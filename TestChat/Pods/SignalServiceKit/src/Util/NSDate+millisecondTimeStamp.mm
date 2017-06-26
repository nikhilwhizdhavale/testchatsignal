//  Created by Frederic Jacobs on 25/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import <chrono>
#import "NSDate+millisecondTimeStamp.h"

@implementation NSDate (millisecondTimeStamp)

+ (uint64_t)ows_millisecondTimeStamp {
    uint64_t milliseconds =
        (uint64_t)(std::chrono::system_clock::now().time_since_epoch() / std::chrono::milliseconds(1));
    return milliseconds;
}

+ (NSDate *)ows_dateWithMillisecondsSince1970:(uint64_t)milliseconds
{
    return [NSDate dateWithTimeIntervalSince1970:(milliseconds / 1000.0)];
}

+ (uint64_t)ows_millisecondsSince1970ForDate:(NSDate *)date
{
    return (uint64_t)(date.timeIntervalSince1970 * 1000);
}

@end
