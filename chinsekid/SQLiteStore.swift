import Foundation
import CoreFoundation

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ChildProfile: Identifiable, Equatable {
    let id: String
    var name: String
    var avatar: String
    var avatarFilename: String? = nil
}

struct SnakeRewardStatus: Equatable {
    var completedQuestions: Int = 0
    var ticketCount: Int = 0
    var hasPlayed = false

    var hasTicket: Bool { ticketCount > 0 }

    static let alphabetRoundQuestionGoal = 26
    static let locked = SnakeRewardStatus()
}

enum LearningStatus: String {
    case new
    case practicing
    case mastered

    var label: String {
        switch self {
        case .new: "新发现"
        case .practicing: "再练练"
        case .mastered: "已认识"
        }
    }
}

struct LearningCharacter: Identifiable {
    var id: String { glyph }
    let glyph: String
    let pinyin: String
    let meaning: String
    let status: LearningStatus
    let pronunciations: [CharacterPronunciation]
}

struct PracticeCharacterSet: Identifiable {
    let id: String
    var name: String
    var glyphs: [String]
    var createdAt: Date
}

@MainActor
final class SQLiteStore {
    private var database: OpaquePointer?
    private let characterData = StrokeOrderStore()

    init() throws {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let databaseURL = directory.appendingPathComponent("hanzi-adventure.sqlite")
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw makeError()
        }
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try migrate()
        try ensureStarterProfile()
    }

    deinit {
        sqlite3_close(database)
    }

    func users() throws -> [ChildProfile] {
        let statement = try prepare("SELECT id, display_name, avatar_filename FROM users ORDER BY created_at;")
        defer { sqlite3_finalize(statement) }
        var result: [ChildProfile] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = text(statement, column: 0)
            let filename = text(statement, column: 2)
            result.append(ChildProfile(
                id: id,
                name: text(statement, column: 1),
                avatar: avatar(for: id),
                avatarFilename: filename.isEmpty ? nil : filename
            ))
        }
        return result
    }

    func addUser(name: String) throws -> ChildProfile {
        let id = UUID().uuidString
        let statement = try prepare("INSERT INTO users(id, display_name, created_at) VALUES(?, ?, ?);")
        defer { sqlite3_finalize(statement) }
        bind(id, to: statement, at: 1)
        bind(name, to: statement, at: 2)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        try stepDone(statement)
        return ChildProfile(id: id, name: name, avatar: avatar(for: id))
    }

    func renameUser(id: String, name: String) throws {
        let statement = try prepare("UPDATE users SET display_name = ? WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        bind(id, to: statement, at: 2)
        try stepDone(statement)
    }

    func deleteUser(id: String) throws {
        let statement = try prepare("DELETE FROM users WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(id, to: statement, at: 1)
        try stepDone(statement)
    }

    func setAvatarFilename(_ filename: String, forUserID userID: String) throws {
        let statement = try prepare("UPDATE users SET avatar_filename = ? WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(filename, to: statement, at: 1)
        bind(userID, to: statement, at: 2)
        try stepDone(statement)
    }

    func characters(for userID: String) throws -> [LearningCharacter] {
        let statement = try prepare("""
            SELECT c.glyph, c.pinyin, c.meaning, uc.status, c.readings_json
            FROM user_characters uc
            JOIN characters c ON c.id = uc.character_id
            WHERE uc.user_id = ?
            ORDER BY uc.created_at DESC;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        var result: [LearningCharacter] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(LearningCharacter(
                glyph: text(statement, column: 0),
                pinyin: text(statement, column: 1),
                meaning: text(statement, column: 2),
                status: LearningStatus(rawValue: text(statement, column: 3)) ?? .new,
                pronunciations: PolyphonicReadings.options(from: text(statement, column: 4))
            ))
        }
        return result
    }

    func listeningMistakes(for userID: String) throws -> [LearningCharacter] {
        let statement = try prepare("""
            SELECT c.glyph, c.pinyin, c.meaning, uc.status, c.readings_json
            FROM user_characters uc
            JOIN characters c ON c.id = uc.character_id
            WHERE uc.user_id = ? AND EXISTS (
                SELECT 1 FROM review_records rr
                WHERE rr.user_id = uc.user_id
                  AND rr.character_id = uc.character_id
                  AND rr.mode = 'listening'
                  AND rr.knew = 0
            )
            ORDER BY uc.updated_at DESC;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        var result: [LearningCharacter] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(LearningCharacter(
                glyph: text(statement, column: 0),
                pinyin: text(statement, column: 1),
                meaning: text(statement, column: 2),
                status: LearningStatus(rawValue: text(statement, column: 3)) ?? .new,
                pronunciations: PolyphonicReadings.options(from: text(statement, column: 4))
            ))
        }
        return result
    }

    func practiceSets(for userID: String) throws -> [PracticeCharacterSet] {
        let statement = try prepare("""
            SELECT id, name, created_at
            FROM practice_sets
            WHERE user_id = ?
            ORDER BY updated_at DESC, created_at DESC;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        var sets: [PracticeCharacterSet] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = text(statement, column: 0)
            let name = text(statement, column: 1)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            let glyphsStatement = try prepare("""
                SELECT c.glyph
                FROM practice_set_characters psc
                JOIN characters c ON c.id = psc.character_id
                WHERE psc.set_id = ? AND psc.user_id = ?
                ORDER BY psc.added_at, c.glyph;
                """)
            bind(id, to: glyphsStatement, at: 1)
            bind(userID, to: glyphsStatement, at: 2)
            var glyphs: [String] = []
            while sqlite3_step(glyphsStatement) == SQLITE_ROW {
                glyphs.append(text(glyphsStatement, column: 0))
            }
            sqlite3_finalize(glyphsStatement)
            sets.append(PracticeCharacterSet(id: id, name: name, glyphs: glyphs, createdAt: createdAt))
        }
        return sets
    }

    func savePracticeSet(id existingID: String?, name: String, glyphs: [String], userID: String) throws -> String {
        guard database != nil else { throw makeError() }
        let setID = existingID ?? UUID().uuidString
        let now = Date().timeIntervalSince1970
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let existingID {
                let update = try prepare("UPDATE practice_sets SET name = ?, updated_at = ? WHERE id = ? AND user_id = ?;")
                bind(name, to: update, at: 1)
                sqlite3_bind_double(update, 2, now)
                bind(existingID, to: update, at: 3)
                bind(userID, to: update, at: 4)
                try stepDone(update)
                let foundSet = sqlite3_changes(database) == 1
                sqlite3_finalize(update)
                guard foundSet else { throw makeError() }

                let removeCharacters = try prepare("DELETE FROM practice_set_characters WHERE set_id = ? AND user_id = ?;")
                bind(existingID, to: removeCharacters, at: 1)
                bind(userID, to: removeCharacters, at: 2)
                try stepDone(removeCharacters)
                sqlite3_finalize(removeCharacters)
            } else {
                let insert = try prepare("INSERT INTO practice_sets(id, user_id, name, created_at, updated_at) VALUES(?, ?, ?, ?, ?);")
                bind(setID, to: insert, at: 1)
                bind(userID, to: insert, at: 2)
                bind(name, to: insert, at: 3)
                sqlite3_bind_double(insert, 4, now)
                sqlite3_bind_double(insert, 5, now)
                try stepDone(insert)
                sqlite3_finalize(insert)
            }

            let insertCharacter = try prepare("""
                INSERT OR IGNORE INTO practice_set_characters(set_id, user_id, character_id, added_at)
                SELECT ?, ?, uc.character_id, ?
                FROM user_characters uc
                JOIN characters c ON c.id = uc.character_id
                WHERE uc.user_id = ? AND c.glyph = ?;
                """)
            defer { sqlite3_finalize(insertCharacter) }
            for glyph in Set(glyphs) {
                sqlite3_reset(insertCharacter)
                sqlite3_clear_bindings(insertCharacter)
                bind(setID, to: insertCharacter, at: 1)
                bind(userID, to: insertCharacter, at: 2)
                sqlite3_bind_double(insertCharacter, 3, now)
                bind(userID, to: insertCharacter, at: 4)
                bind(glyph, to: insertCharacter, at: 5)
                try stepDone(insertCharacter)
            }
            let countStatement = try prepare("SELECT COUNT(*) FROM practice_set_characters WHERE set_id = ? AND user_id = ?;")
            bind(setID, to: countStatement, at: 1)
            bind(userID, to: countStatement, at: 2)
            let count = sqlite3_step(countStatement) == SQLITE_ROW ? sqlite3_column_int(countStatement, 0) : 0
            sqlite3_finalize(countStatement)
            guard count > 0 else { throw makeError() }
            try execute("COMMIT;")
            return setID
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func deletePracticeSet(id: String, userID: String) throws {
        let statement = try prepare("DELETE FROM practice_sets WHERE id = ? AND user_id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(id, to: statement, at: 1)
        bind(userID, to: statement, at: 2)
        try stepDone(statement)
    }

    func importCharacters(_ glyphs: [String], for userID: String) throws -> (added: Int, existing: Int) {
        guard let database else { throw makeError() }
        var added = 0
        var existing = 0
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            for glyph in glyphs where Self.isSingleHanCharacter(glyph) {
                let insertCharacter = try prepare("""
                    INSERT INTO characters(glyph, pinyin, readings_json) VALUES(?, ?, ?)
                    ON CONFLICT(glyph) DO UPDATE SET pinyin =
                        CASE WHEN excluded.readings_json != '[]' THEN excluded.pinyin
                             WHEN characters.pinyin = '' THEN excluded.pinyin ELSE characters.pinyin END,
                        readings_json = CASE WHEN excluded.readings_json != '[]' THEN excluded.readings_json
                                             ELSE characters.readings_json END;
                    """)
                bind(glyph, to: insertCharacter, at: 1)
                let options = PolyphonicReadings.catalog[glyph] ?? []
                bind(options.first?.pinyin ?? characterData.pinyin(for: glyph) ?? Self.pinyin(for: glyph), to: insertCharacter, at: 2)
                bind(PolyphonicReadings.encodedOptions(for: glyph), to: insertCharacter, at: 3)
                try stepDone(insertCharacter)
                sqlite3_finalize(insertCharacter)

                let selectCharacter = try prepare("SELECT id FROM characters WHERE glyph = ?;")
                bind(glyph, to: selectCharacter, at: 1)
                guard sqlite3_step(selectCharacter) == SQLITE_ROW else {
                    sqlite3_finalize(selectCharacter)
                    throw makeError()
                }
                let characterID = sqlite3_column_int64(selectCharacter, 0)
                sqlite3_finalize(selectCharacter)

                let addToUser = try prepare("""
                    INSERT INTO user_characters(user_id, character_id, status, review_at, created_at, updated_at)
                    VALUES(?, ?, 'new', ?, ?, ?)
                    ON CONFLICT(user_id, character_id) DO NOTHING;
                    """)
                bind(userID, to: addToUser, at: 1)
                sqlite3_bind_int64(addToUser, 2, characterID)
                let now = Date().timeIntervalSince1970
                sqlite3_bind_double(addToUser, 3, now)
                sqlite3_bind_double(addToUser, 4, now)
                sqlite3_bind_double(addToUser, 5, now)
                try stepDone(addToUser)
                if sqlite3_changes(database) == 1 { added += 1 } else { existing += 1 }
                sqlite3_finalize(addToUser)
            }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
        return (added, existing)
    }

    func recordAnswer(userID: String, glyph: String, knew: Bool) throws {
        let findCharacter = try prepare("SELECT id FROM characters WHERE glyph = ?;")
        defer { sqlite3_finalize(findCharacter) }
        bind(glyph, to: findCharacter, at: 1)
        guard sqlite3_step(findCharacter) == SQLITE_ROW else { return }
        let characterID = sqlite3_column_int64(findCharacter, 0)
        let now = Date().timeIntervalSince1970
        let nextReview = now + (knew ? 86_400 : 60)
        let status = knew ? LearningStatus.mastered.rawValue : LearningStatus.practicing.rawValue

        let update = try prepare("""
            UPDATE user_characters
            SET status = ?, review_at = ?, updated_at = ?
            WHERE user_id = ? AND character_id = ?;
            """)
        bind(status, to: update, at: 1)
        sqlite3_bind_double(update, 2, nextReview)
        sqlite3_bind_double(update, 3, now)
        bind(userID, to: update, at: 4)
        sqlite3_bind_int64(update, 5, characterID)
        try stepDone(update)
        sqlite3_finalize(update)

        let record = try prepare("""
            INSERT INTO review_records(id, user_id, character_id, knew, reviewed_at, mode, answer_glyph)
            VALUES(?, ?, ?, ?, ?, 'flashcard', ?);
            """)
        bind(UUID().uuidString, to: record, at: 1)
        bind(userID, to: record, at: 2)
        sqlite3_bind_int64(record, 3, characterID)
        sqlite3_bind_int(record, 4, knew ? 1 : 0)
        sqlite3_bind_double(record, 5, now)
        bind(glyph, to: record, at: 6)
        try stepDone(record)
        sqlite3_finalize(record)
    }

    func recordListeningAnswer(userID: String, targetGlyph: String, answerGlyph: String, correct: Bool) throws {
        guard database != nil else { throw makeError() }
        let findCharacter = try prepare("SELECT id FROM characters WHERE glyph = ?;")
        defer { sqlite3_finalize(findCharacter) }
        bind(targetGlyph, to: findCharacter, at: 1)
        guard sqlite3_step(findCharacter) == SQLITE_ROW else { return }
        let characterID = sqlite3_column_int64(findCharacter, 0)
        let now = Date().timeIntervalSince1970
        let nextReview = now + (correct ? 86_400 : 60)
        let status = correct ? LearningStatus.mastered.rawValue : LearningStatus.practicing.rawValue

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let update = try prepare("""
                UPDATE user_characters
                SET status = ?, review_at = ?, updated_at = ?
                WHERE user_id = ? AND character_id = ?;
                """)
            bind(status, to: update, at: 1)
            sqlite3_bind_double(update, 2, nextReview)
            sqlite3_bind_double(update, 3, now)
            bind(userID, to: update, at: 4)
            sqlite3_bind_int64(update, 5, characterID)
            try stepDone(update)
            sqlite3_finalize(update)

            let record = try prepare("""
                INSERT INTO review_records(id, user_id, character_id, knew, reviewed_at, mode, answer_glyph)
                VALUES(?, ?, ?, ?, ?, 'listening', ?);
                """)
            bind(UUID().uuidString, to: record, at: 1)
            bind(userID, to: record, at: 2)
            sqlite3_bind_int64(record, 3, characterID)
            sqlite3_bind_int(record, 4, correct ? 1 : 0)
            sqlite3_bind_double(record, 5, now)
            bind(answerGlyph, to: record, at: 6)
            try stepDone(record)
            sqlite3_finalize(record)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func studySet(for userID: String, limit: Int = 8) throws -> [LearningCharacter] {
        let statement = try prepare("""
            SELECT c.glyph, c.pinyin, c.meaning, uc.status, c.readings_json
            FROM user_characters uc
            JOIN characters c ON c.id = uc.character_id
            WHERE uc.user_id = ? AND (uc.status != 'mastered' OR uc.review_at <= ?)
            ORDER BY CASE WHEN uc.review_at <= ? THEN 0 ELSE 1 END, RANDOM()
            LIMIT ?;
            """)
        defer { sqlite3_finalize(statement) }
        let now = Date().timeIntervalSince1970
        bind(userID, to: statement, at: 1)
        sqlite3_bind_double(statement, 2, now)
        sqlite3_bind_double(statement, 3, now)
        sqlite3_bind_int(statement, 4, Int32(limit))
        var result: [LearningCharacter] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(LearningCharacter(
                glyph: text(statement, column: 0), pinyin: text(statement, column: 1),
                meaning: text(statement, column: 2), status: LearningStatus(rawValue: text(statement, column: 3)) ?? .new,
                pronunciations: PolyphonicReadings.options(from: text(statement, column: 4))
            ))
        }
        if result.isEmpty {
            let all = try characters(for: userID).shuffled()
            return Array(all.prefix(limit))
        }
        return result
    }

    func progress(for userID: String) throws -> (learned: Int, due: Int) {
        let statement = try prepare("""
            SELECT
                COALESCE(SUM(CASE WHEN status = 'mastered' THEN 1 ELSE 0 END), 0),
                COALESCE(SUM(CASE WHEN status != 'mastered' OR review_at <= ? THEN 1 ELSE 0 END), 0)
            FROM user_characters WHERE user_id = ?;
            """)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        bind(userID, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw makeError() }
        return (Int(sqlite3_column_int(statement, 0)), Int(sqlite3_column_int(statement, 1)))
    }

    func studiedPinyinItems(for userID: String) throws -> Set<String> {
        let statement = try prepare("SELECT item_id FROM pinyin_progress WHERE user_id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        var result: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.insert(text(statement, column: 0))
        }
        return result
    }

    func recordPinyinStudy(userID: String, itemID: String) throws {
        let statement = try prepare("""
            INSERT INTO pinyin_progress(user_id, item_id, studied_at) VALUES(?, ?, ?)
            ON CONFLICT(user_id, item_id) DO UPDATE SET studied_at = excluded.studied_at;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        bind(itemID, to: statement, at: 2)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        try stepDone(statement)
    }

    func studiedAlphabetLetters(for userID: String) throws -> Set<String> {
        let statement = try prepare("SELECT letter FROM alphabet_progress WHERE user_id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        var result: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.insert(text(statement, column: 0))
        }
        return result
    }

    func recordAlphabetStudy(userID: String, letter: String) throws {
        let statement = try prepare("""
            INSERT INTO alphabet_progress(user_id, letter, studied_at) VALUES(?, ?, ?)
            ON CONFLICT(user_id, letter) DO UPDATE SET studied_at = excluded.studied_at;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        bind(letter.uppercased(), to: statement, at: 2)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        try stepDone(statement)
    }

    func snakeRewardStatus(for userID: String) throws -> SnakeRewardStatus {
        let statement = try prepare("SELECT completed_questions, ticket_count, has_played FROM snake_daily_rewards WHERE user_id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return .locked
        }
        return SnakeRewardStatus(
            completedQuestions: Int(sqlite3_column_int(statement, 0)),
            ticketCount: Int(sqlite3_column_int(statement, 1)),
            hasPlayed: sqlite3_column_int(statement, 2) != 0
        )
    }

    @discardableResult
    func resetAlphabetSnakePracticeProgress(userID: String) throws -> SnakeRewardStatus {
        let statement = try prepare("""
            INSERT INTO snake_daily_rewards(user_id, day_key, completed_questions, has_ticket, has_played)
            VALUES(?, ?, 0, 0, 0)
            ON CONFLICT(user_id) DO UPDATE SET
                day_key = excluded.day_key,
                completed_questions = 0,
                has_ticket = CASE WHEN snake_daily_rewards.ticket_count > 0 THEN 1 ELSE 0 END,
                has_played = snake_daily_rewards.has_played;
            """)
        defer { sqlite3_finalize(statement) }
        bind(userID, to: statement, at: 1)
        bind(currentDayKey(), to: statement, at: 2)
        try stepDone(statement)
        return try snakeRewardStatus(for: userID)
    }

    @discardableResult
    func recordAlphabetSnakePracticeAnswer(userID: String, isCorrect: Bool) throws -> SnakeRewardStatus {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let current = try snakeRewardStatus(for: userID)
            guard current.completedQuestions < SnakeRewardStatus.alphabetRoundQuestionGoal else {
                try execute("COMMIT;")
                return current
            }

            let completed = isCorrect
                ? min(current.completedQuestions + 1, SnakeRewardStatus.alphabetRoundQuestionGoal)
                : 0
            let earnedTicket = isCorrect && completed == SnakeRewardStatus.alphabetRoundQuestionGoal
            let ticketCount = current.ticketCount + (earnedTicket ? 1 : 0)
            let statement = try prepare("""
                INSERT INTO snake_daily_rewards(user_id, day_key, completed_questions, has_ticket, has_played, ticket_count)
                VALUES(?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    day_key = excluded.day_key,
                    completed_questions = excluded.completed_questions,
                    has_ticket = excluded.has_ticket,
                    has_played = excluded.has_played,
                    ticket_count = excluded.ticket_count;
                """)
            defer { sqlite3_finalize(statement) }
            bind(userID, to: statement, at: 1)
            bind(currentDayKey(), to: statement, at: 2)
            sqlite3_bind_int(statement, 3, Int32(completed))
            sqlite3_bind_int(statement, 4, ticketCount > 0 ? 1 : 0)
            sqlite3_bind_int(statement, 5, current.hasPlayed ? 1 : 0)
            sqlite3_bind_int(statement, 6, Int32(ticketCount))
            try stepDone(statement)
            try execute("COMMIT;")
            return SnakeRewardStatus(completedQuestions: completed, ticketCount: ticketCount, hasPlayed: current.hasPlayed)
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func consumeSnakeTicket(userID: String, count: Int = 1) throws -> Bool {
        guard count > 0 else { return false }
        let statement = try prepare("""
            UPDATE snake_daily_rewards
            SET completed_questions = 0, ticket_count = ticket_count - ?,
                has_ticket = CASE WHEN ticket_count - ? > 0 THEN 1 ELSE 0 END,
                has_played = 1
            WHERE user_id = ? AND ticket_count >= ?;
            """)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(count))
        sqlite3_bind_int(statement, 2, Int32(count))
        bind(userID, to: statement, at: 3)
        sqlite3_bind_int(statement, 4, Int32(count))
        try stepDone(statement)
        return sqlite3_changes(database) == 1
    }

    func awardFishPracticeTicket(userID: String, roundID: String) throws -> Bool {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let isNewAward: Bool
            do {
                let award = try prepare("INSERT OR IGNORE INTO fish_ticket_awards(round_id, user_id) VALUES(?, ?);")
                defer { sqlite3_finalize(award) }
                bind(roundID, to: award, at: 1)
                bind(userID, to: award, at: 2)
                try stepDone(award)
                isNewAward = sqlite3_changes(database) == 1
            }
            guard isNewAward else {
                try execute("COMMIT;")
                return false
            }
            do {
                let update = try prepare("""
                    INSERT INTO snake_daily_rewards(user_id, day_key, completed_questions, has_ticket, has_played, ticket_count)
                    VALUES(?, ?, 0, 1, 0, 1)
                    ON CONFLICT(user_id) DO UPDATE SET ticket_count = ticket_count + 1, has_ticket = 1;
                    """)
                defer { sqlite3_finalize(update) }
                bind(userID, to: update, at: 1)
                bind(currentDayKey(), to: update, at: 2)
                try stepDone(update)
            }
            try execute("COMMIT;")
            return true
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func currentDayKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func migrate() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at REAL NOT NULL
            );
            """)
        var current = try scalarInt("SELECT COALESCE(MAX(version), 0) FROM schema_migrations;")
        if current < 1 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE users (
                        id TEXT PRIMARY KEY NOT NULL,
                        display_name TEXT NOT NULL,
                        created_at REAL NOT NULL
                    );
                    CREATE TABLE characters (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        glyph TEXT NOT NULL UNIQUE,
                        pinyin TEXT NOT NULL DEFAULT '',
                        meaning TEXT NOT NULL DEFAULT ''
                    );
                    CREATE TABLE user_characters (
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
                        status TEXT NOT NULL DEFAULT 'new' CHECK(status IN ('new', 'practicing', 'mastered')),
                        review_at REAL NOT NULL,
                        created_at REAL NOT NULL,
                        updated_at REAL NOT NULL,
                        PRIMARY KEY(user_id, character_id)
                    );
                    CREATE TABLE review_records (
                        id TEXT PRIMARY KEY NOT NULL,
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
                        knew INTEGER NOT NULL CHECK(knew IN (0, 1)),
                        reviewed_at REAL NOT NULL
                    );
                    CREATE INDEX idx_user_characters_due ON user_characters(user_id, status, review_at);
                    CREATE INDEX idx_review_records_user_date ON review_records(user_id, reviewed_at);
                    INSERT INTO schema_migrations(version, applied_at) VALUES(1, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
                current = 1
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 2 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    ALTER TABLE review_records ADD COLUMN mode TEXT NOT NULL DEFAULT 'flashcard';
                    ALTER TABLE review_records ADD COLUMN answer_glyph TEXT NOT NULL DEFAULT '';
                    INSERT INTO schema_migrations(version, applied_at) VALUES(2, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 3 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try backfillMissingPinyin()
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(3, strftime('%s','now'));")
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 4 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try backfillDictionaryPinyin()
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(4, strftime('%s','now'));")
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 5 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("ALTER TABLE users ADD COLUMN avatar_filename TEXT NOT NULL DEFAULT '';")
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(5, strftime('%s','now'));")
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 6 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE practice_sets (
                        id TEXT PRIMARY KEY NOT NULL,
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        name TEXT NOT NULL,
                        created_at REAL NOT NULL,
                        updated_at REAL NOT NULL,
                        UNIQUE(id, user_id)
                    );
                    CREATE TABLE practice_set_characters (
                        set_id TEXT NOT NULL,
                        user_id TEXT NOT NULL,
                        character_id INTEGER NOT NULL,
                        added_at REAL NOT NULL,
                        PRIMARY KEY(set_id, character_id),
                        FOREIGN KEY(set_id, user_id) REFERENCES practice_sets(id, user_id) ON DELETE CASCADE,
                        FOREIGN KEY(user_id, character_id) REFERENCES user_characters(user_id, character_id) ON DELETE CASCADE
                    );
                    CREATE INDEX idx_practice_sets_user ON practice_sets(user_id, updated_at DESC);
                    INSERT INTO schema_migrations(version, applied_at) VALUES(6, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 7 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("ALTER TABLE characters ADD COLUMN readings_json TEXT NOT NULL DEFAULT '[]';")
                try backfillPolyphonicReadings()
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(7, strftime('%s','now'));")
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 8 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try backfillPolyphonicReadings()
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(8, strftime('%s','now'));")
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 9 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE pinyin_progress (
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        item_id TEXT NOT NULL,
                        studied_at REAL NOT NULL,
                        PRIMARY KEY(user_id, item_id)
                    );
                    CREATE INDEX idx_pinyin_progress_user ON pinyin_progress(user_id, studied_at DESC);
                    INSERT INTO schema_migrations(version, applied_at) VALUES(9, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 10 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE alphabet_progress (
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        letter TEXT NOT NULL CHECK(length(letter) = 1),
                        studied_at REAL NOT NULL,
                        PRIMARY KEY(user_id, letter)
                    );
                    CREATE INDEX idx_alphabet_progress_user ON alphabet_progress(user_id, studied_at DESC);
                    INSERT INTO schema_migrations(version, applied_at) VALUES(10, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 11 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE snake_daily_rewards (
                        user_id TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        day_key TEXT NOT NULL,
                        completed_questions INTEGER NOT NULL DEFAULT 0 CHECK(completed_questions BETWEEN 0 AND 5),
                        has_ticket INTEGER NOT NULL DEFAULT 0 CHECK(has_ticket IN (0, 1)),
                        has_played INTEGER NOT NULL DEFAULT 0 CHECK(has_played IN (0, 1))
                    );
                    INSERT INTO schema_migrations(version, applied_at) VALUES(11, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 12 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE snake_daily_rewards_v12 (
                        user_id TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        day_key TEXT NOT NULL,
                        completed_questions INTEGER NOT NULL DEFAULT 0 CHECK(completed_questions BETWEEN 0 AND 26),
                        has_ticket INTEGER NOT NULL DEFAULT 0 CHECK(has_ticket IN (0, 1)),
                        has_played INTEGER NOT NULL DEFAULT 0 CHECK(has_played IN (0, 1))
                    );
                    INSERT INTO snake_daily_rewards_v12(user_id, day_key, completed_questions, has_ticket, has_played)
                    SELECT user_id, day_key, 0, has_ticket, has_played FROM snake_daily_rewards;
                    DROP TABLE snake_daily_rewards;
                    ALTER TABLE snake_daily_rewards_v12 RENAME TO snake_daily_rewards;
                    INSERT INTO schema_migrations(version, applied_at) VALUES(12, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
                current = 12
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 13 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    ALTER TABLE snake_daily_rewards
                        ADD COLUMN ticket_count INTEGER NOT NULL DEFAULT 0 CHECK(ticket_count >= 0);
                    UPDATE snake_daily_rewards SET ticket_count = has_ticket;
                    INSERT INTO schema_migrations(version, applied_at) VALUES(13, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
                current = 13
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
        if current < 14 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute("""
                    CREATE TABLE fish_ticket_awards (
                        round_id TEXT PRIMARY KEY NOT NULL,
                        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE
                    );
                    INSERT INTO schema_migrations(version, applied_at) VALUES(14, strftime('%s','now'));
                    """)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    private func backfillPolyphonicReadings() throws {
        let update = try prepare("UPDATE characters SET pinyin = ?, readings_json = ? WHERE glyph = ?;")
        defer { sqlite3_finalize(update) }
        for (glyph, options) in PolyphonicReadings.catalog {
            guard let first = options.first else { continue }
            sqlite3_reset(update)
            sqlite3_clear_bindings(update)
            bind(first.pinyin, to: update, at: 1)
            bind(PolyphonicReadings.encodedOptions(for: glyph), to: update, at: 2)
            bind(glyph, to: update, at: 3)
            try stepDone(update)
        }
    }

    private func backfillMissingPinyin() throws {
        let query = try prepare("SELECT id, glyph FROM characters WHERE pinyin = '';")
        defer { sqlite3_finalize(query) }
        var missing: [(Int64, String)] = []
        while sqlite3_step(query) == SQLITE_ROW {
            missing.append((sqlite3_column_int64(query, 0), text(query, column: 1)))
        }

        let update = try prepare("UPDATE characters SET pinyin = ? WHERE id = ? AND pinyin = '';")
        defer { sqlite3_finalize(update) }
        for (id, glyph) in missing {
            let pronunciation = characterData.pinyin(for: glyph) ?? Self.pinyin(for: glyph)
            guard !pronunciation.isEmpty else { continue }
            sqlite3_reset(update)
            sqlite3_clear_bindings(update)
            bind(pronunciation, to: update, at: 1)
            sqlite3_bind_int64(update, 2, id)
            try stepDone(update)
        }
    }

    private func backfillDictionaryPinyin() throws {
        let query = try prepare("SELECT id, glyph FROM characters;")
        defer { sqlite3_finalize(query) }
        var characters: [(Int64, String)] = []
        while sqlite3_step(query) == SQLITE_ROW {
            characters.append((sqlite3_column_int64(query, 0), text(query, column: 1)))
        }

        let update = try prepare("UPDATE characters SET pinyin = ? WHERE id = ?;")
        defer { sqlite3_finalize(update) }
        for (id, glyph) in characters {
            guard let pronunciation = characterData.pinyin(for: glyph) else { continue }
            sqlite3_reset(update)
            sqlite3_clear_bindings(update)
            bind(pronunciation, to: update, at: 1)
            sqlite3_bind_int64(update, 2, id)
            try stepDone(update)
        }
    }

    private static func pinyin(for glyph: String) -> String {
        let mutable = NSMutableString(string: glyph) as CFMutableString
        guard CFStringTransform(mutable, nil, kCFStringTransformToLatin, false) else { return "" }
        let transformed = (mutable as String).lowercased()
        guard transformed != glyph else { return "" }
        return transformed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func ensureStarterProfile() throws {
        let count = try scalarInt("SELECT COUNT(*) FROM users;")
        guard count == 0 else { return }
        let profile = try addUser(name: "小小探险家")
        let samples: [(String, String, String)] = [
            ("山", "shān", "山峰"), ("水", "shuǐ", "河水"), ("日", "rì", "太阳"),
            ("月", "yuè", "月亮"), ("花", "huā", "花朵"), ("木", "mù", "树木")
        ]
        for sample in samples {
            let insert = try prepare("INSERT INTO characters(glyph, pinyin, meaning) VALUES(?, ?, ?) ON CONFLICT(glyph) DO UPDATE SET pinyin = excluded.pinyin, meaning = excluded.meaning;")
            bind(sample.0, to: insert, at: 1)
            bind(sample.1, to: insert, at: 2)
            bind(sample.2, to: insert, at: 3)
            try stepDone(insert)
            sqlite3_finalize(insert)
            let relation = try prepare("""
                INSERT OR IGNORE INTO user_characters(user_id, character_id, status, review_at, created_at, updated_at)
                SELECT ?, id, 'new', ?, ?, ? FROM characters WHERE glyph = ?;
                """)
            let now = Date().timeIntervalSince1970
            bind(profile.id, to: relation, at: 1)
            sqlite3_bind_double(relation, 2, now)
            sqlite3_bind_double(relation, 3, now)
            sqlite3_bind_double(relation, 4, now)
            bind(sample.0, to: relation, at: 5)
            try stepDone(relation)
            sqlite3_finalize(relation)
        }
    }

    private func avatar(for id: String) -> String {
        let animals = ["🦊", "🐼", "🐻", "🐰", "🐯", "🐸"]
        let index = abs(id.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % animals.count
        return animals[index]
    }

    private static func isSingleHanCharacter(_ value: String) -> Bool {
        guard value.count == 1, let scalar = value.unicodeScalars.first else { return false }
        let number = scalar.value
        return (0x3400...0x4DBF).contains(number) || (0x4E00...0x9FFF).contains(number) || (0xF900...0xFAFF).contains(number)
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "SQLite 执行失败"
            sqlite3_free(errorMessage)
            throw NSError(domain: "SQLiteStore", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw makeError()
        }
        return statement
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw makeError() }
    }

    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: pointer)
    }

    private func scalarInt(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw makeError() }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func makeError() -> NSError {
        let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "无法打开 SQLite 数据库"
        return NSError(domain: "SQLiteStore", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
