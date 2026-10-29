#import <Foundation/Foundation.h>
#import <stdlib.h>
#import <string.h>

extern "C" void ChinsekidFishGameDidFinish(int score, int level, int eaten) {
    NSDictionary *payload = @{
        @"score": @(score),
        @"level": @(level),
        @"eaten": @(eaten)
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Chinsekid.UnityFishGameDidFinish" object:nil userInfo:payload];
    });
}

extern "C" const char *ChinsekidFishGameCopySelectedSkin(void) {
    NSString *skin = [[NSUserDefaults standardUserDefaults] stringForKey:@"Chinsekid.UnityFishSelectedSkin"] ?: @"clownfish";
    return strdup(skin.UTF8String);
}

extern "C" const char *ChinsekidFishGameCopyDifficulty(void) {
    NSString *difficulty = [[NSUserDefaults standardUserDefaults] stringForKey:@"Chinsekid.UnityFishDifficulty"] ?: @"standard";
    return strdup(difficulty.UTF8String);
}

extern "C" void ChinsekidFishGameFreeString(const char *value) {
    free((void *)value);
}
