import Foundation

final class StrokeOrderStore {
    private var database: OpaquePointer?

    init(bundle: Bundle = .main) {
        let assetURL = bundle.url(forResource: "StrokeOrders", withExtension: "sqlite", subdirectory: "Resources")
            ?? bundle.url(forResource: "StrokeOrders", withExtension: "sqlite")
        guard let assetURL else { return }
        sqlite3_open_v2(assetURL.path, &database, SQLITE_OPEN_READONLY, nil)
    }

    deinit {
        sqlite3_close(database)
    }

    func pinyin(for glyph: String) -> String? {
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT pinyin FROM stroke_orders WHERE glyph = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK,
              let statement else { return nil }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bindResult = glyph.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
        guard bindResult == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let rawPinyin = sqlite3_column_text(statement, 0) else { return nil }
        let value = String(cString: rawPinyin)
        return value.isEmpty ? nil : value
    }

    func strokes(for glyph: String) -> [String] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT strokes_zlib, decoded_size FROM stroke_orders WHERE glyph = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK,
              let statement else { return [] }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bindResult = glyph.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
        guard bindResult == SQLITE_OK else { return [] }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let data = decodedData(statement: statement, blobColumn: 0, sizeColumn: 1) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func medians(for glyph: String) -> [[[Double]]] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT medians_zlib, medians_decoded_size FROM stroke_orders WHERE glyph = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK,
              let statement else { return [] }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bindResult = glyph.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
        guard bindResult == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let data = decodedData(statement: statement, blobColumn: 0, sizeColumn: 1) else { return [] }
        return (try? JSONDecoder().decode([[[Double]]].self, from: data)) ?? []
    }

    private func decodedData(statement: OpaquePointer, blobColumn: Int32, sizeColumn: Int32) -> Data? {
        guard let compressed = sqlite3_column_blob(statement, blobColumn) else { return nil }
        let compressedSize = Int(sqlite3_column_bytes(statement, blobColumn))
        let decodedSize = Int(sqlite3_column_int(statement, sizeColumn))
        guard compressedSize > 0, decodedSize > 0 else { return nil }
        var data = Data(count: decodedSize)
        var outputSize = uLongf(decodedSize)
        let decodeResult = data.withUnsafeMutableBytes { destination in
            uncompress(
                destination.bindMemory(to: Bytef.self).baseAddress!,
                &outputSize,
                compressed.assumingMemoryBound(to: Bytef.self),
                uLong(compressedSize)
            )
        }
        guard decodeResult == Z_OK, outputSize == uLongf(decodedSize) else { return nil }
        return data
    }
}
