// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXNotifications/EXNotificationSerializer.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation EXNotificationSerializer

+ (NSDictionary *)serializedNotificationResponse:(UNNotificationResponse *)response
{
  NSMutableDictionary *serializedResponse = [NSMutableDictionary dictionary];
  serializedResponse[@"actionIdentifier"] = response.actionIdentifier ?: [NSNull null];
  serializedResponse[@"notification"] = [self serializedNotification:response.notification];
  if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
    UNTextInputNotificationResponse *textInputResponse = (UNTextInputNotificationResponse *)response;
    serializedResponse[@"userText"] = textInputResponse.userText ?: [NSNull null];
  }
  return serializedResponse;
}

+ (NSDictionary *)serializedNotification:(UNNotification *)notification
{
  NSMutableDictionary *serializedNotification = [NSMutableDictionary dictionary];
  serializedNotification[@"request"] = [self serializedNotificationRequest:notification.request];
  serializedNotification[@"date"] = @(notification.date.timeIntervalSince1970);
  return serializedNotification;
}

+ (NSDictionary *)serializedNotificationRequest:(UNNotificationRequest *)request
{
  NSMutableDictionary *serializedRequest = [NSMutableDictionary dictionary];
  serializedRequest[@"identifier"] = request.identifier;
  serializedRequest[@"notification"] = [self serializedNotificationContent:request.content];
  serializedRequest[@"trigger"] = [self serializedNotificationTrigger:request.trigger];
  return serializedRequest;
}

+ (NSDictionary *)serializedNotificationContent:(UNNotificationContent *)content
{
  NSMutableDictionary *serializedContent = [NSMutableDictionary dictionary];
  serializedContent[@"title"] = content.title ?: [NSNull null];
  serializedContent[@"subtitle"] = content.subtitle ?: [NSNull null];
  serializedContent[@"body"] = content.body ?: [NSNull null];
  serializedContent[@"badge"] = content.badge ?: [NSNull null];
  serializedContent[@"sound"] = [self serializedNotificationSound:content.sound] ?: [NSNull null];
  serializedContent[@"launchImageName"] = content.launchImageName ?: [NSNull null];
  serializedContent[@"userInfo"] = content.userInfo ?: [NSNull null];
  serializedContent[@"attachments"] = [self serializedNotificationAttachments:content.attachments];

  if (@available(iOS 12.0, *)) {
    serializedContent[@"summaryArgument"] = content.summaryArgument ?: [NSNull null];
    serializedContent[@"summaryArgumentCount"] = @(content.summaryArgumentCount);
  }

  serializedContent[@"categoryIdentifier"] = content.categoryIdentifier ?: [NSNull null];
  serializedContent[@"threadIdentifier"] = content.threadIdentifier ?: [NSNull null];
  if (@available(iOS 13.0, *)) {
    serializedContent[@"targetContentIdentifier"] = content.targetContentIdentifier ?: [NSNull null];
  }

  return serializedContent;
}

+ (NSString *)serializedNotificationSound:(UNNotificationSound *)sound
{
  // nil compared to defaultCriticalSound returns true
  if (!sound) {
    return nil;
  }

  if (@available(iOS 12.0, *)) {
    if ([[UNNotificationSound defaultCriticalSound] isEqual:sound]) {
      return @"defaultCritical";
    }
  }

  if ([[UNNotificationSound defaultSound] isEqual:sound]) {
    return @"default";
  }

  return @"unknown";
}

+ (NSArray *)serializedNotificationAttachments:(NSArray<UNNotificationAttachment *> *)attachments
{
  NSMutableArray *serializedAttachments = [NSMutableArray array];
  for (UNNotificationAttachment *attachment in attachments) {
    [serializedAttachments addObject:[self serializedNotificationAttachment:attachment]];
  }
  return serializedAttachments;
}

+ (NSDictionary *)serializedNotificationAttachment:(UNNotificationAttachment *)attachment
{
  NSMutableDictionary *serializedAttachment = [NSMutableDictionary dictionary];
  serializedAttachment[@"identifier"] = attachment.identifier ?: [NSNull null];
  serializedAttachment[@"url"] = attachment.URL.absoluteString ?: [NSNull null];
  serializedAttachment[@"type"] = attachment.type ?: [NSNull null];
  return serializedAttachment;
}

+ (NSDictionary *)serializedNotificationTrigger:(UNNotificationTrigger *)trigger
{
  NSMutableDictionary *serializedTrigger = [NSMutableDictionary dictionary];
  serializedTrigger[@"class"] = NSStringFromClass(trigger.class);
  serializedTrigger[@"repeats"] = @(trigger.repeats);
  if ([trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
    serializedTrigger[@"type"] = @"push";
  } else if ([trigger isKindOfClass:[UNCalendarNotificationTrigger class]]) {
    serializedTrigger[@"type"] = @"calendar";
    UNCalendarNotificationTrigger *calendarTrigger = (UNCalendarNotificationTrigger *)trigger;
    serializedTrigger[@"dateComponents"] = [self serializedDateComponents:calendarTrigger.dateComponents];
  } else if ([trigger isKindOfClass:[UNLocationNotificationTrigger class]]) {
    serializedTrigger[@"type"] = @"location";
    UNLocationNotificationTrigger *locationTrigger = (UNLocationNotificationTrigger *)trigger;
    serializedTrigger[@"region"] = [self serializedRegion:locationTrigger.region];
  } else if ([trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]) {
    serializedTrigger[@"type"] = @"interval";
    UNTimeIntervalNotificationTrigger *timeIntervalTrigger = (UNTimeIntervalNotificationTrigger *)trigger;
    serializedTrigger[@"value"] = @(timeIntervalTrigger.timeInterval);
  } else {
    serializedTrigger[@"type"] = @"unknown";
  }
  return serializedTrigger;
}

+ (NSDictionary *)serializedDateComponents:(NSDateComponents *)dateComponents
{
  NSMutableDictionary *serializedComponents = [NSMutableDictionary dictionary];
  NSArray<NSNumber *> *autoConvertedUnits = [[self calendarUnitsConversionMap] allKeys];
  for (NSNumber *calendarUnitNumber in autoConvertedUnits) {
    NSCalendarUnit calendarUnit = [calendarUnitNumber unsignedIntegerValue];
    NSInteger unitValue = [dateComponents valueForComponent:calendarUnit];
    if (unitValue != NSDateComponentUndefined) {
      serializedComponents[[self keyForCalendarUnit:calendarUnit]] = @([dateComponents valueForComponent:calendarUnit]);
    }
  }
  serializedComponents[@"calendar"] = dateComponents.calendar.calendarIdentifier ?: [NSNull null];
  serializedComponents[@"timeZone"] = dateComponents.timeZone.description ?: [NSNull null];
  serializedComponents[@"isLeapMonth"] = @(dateComponents.isLeapMonth);
  return serializedComponents;
}

+ (NSDictionary *)calendarUnitsConversionMap
{
  static NSDictionary *keysMap = nil;
  if (!keysMap) {
    keysMap = @{
      @(NSCalendarUnitEra): @"era",
      @(NSCalendarUnitYear): @"year",
      @(NSCalendarUnitMonth): @"month",
      @(NSCalendarUnitDay): @"day",
      @(NSCalendarUnitHour): @"hour",
      @(NSCalendarUnitMinute): @"minute",
      @(NSCalendarUnitSecond): @"second",
      @(NSCalendarUnitWeekday): @"weekday",
      @(NSCalendarUnitWeekdayOrdinal): @"weekdayOrdinal",
      @(NSCalendarUnitQuarter): @"quarter",
      @(NSCalendarUnitWeekOfMonth): @"weekOfMonth",
      @(NSCalendarUnitWeekOfYear): @"weekOfYear",
      @(NSCalendarUnitYearForWeekOfYear): @"yearForWeekOfYear",
      @(NSCalendarUnitNanosecond): @"nanosecond"
      // NSCalendarUnitCalendar and NSCalendarUnitTimeZone
      // should be handled separately
    };
  }
  return keysMap;
}

+ (NSString *)keyForCalendarUnit:(NSCalendarUnit)calendarUnit
{
  return [self calendarUnitsConversionMap][@(calendarUnit)];
}

+ (NSDictionary *)serializedRegion:(CLRegion *)region
{
  NSMutableDictionary *serializedRegion = [NSMutableDictionary dictionary];
  serializedRegion[@"identifier"] = region.identifier;
  serializedRegion[@"notifyOnEntry"] = @(region.notifyOnEntry);
  serializedRegion[@"notifyOnExit"] = @(region.notifyOnExit);
  if ([region isKindOfClass:[CLCircularRegion class]]) {
    serializedRegion[@"type"] = @"circular";
    CLCircularRegion *circularRegion = (CLCircularRegion *)region;
    NSDictionary *serializedCenter = @{
      @"latitude": @(circularRegion.center.latitude),
      @"longitude": @(circularRegion.center.longitude)
    };
    serializedRegion[@"center"] = serializedCenter;
    serializedRegion[@"radius"] = @(circularRegion.radius);
  } else if ([region isKindOfClass:[CLBeaconRegion class]]) {
    serializedRegion[@"type"] = @"beacon";
    CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
    serializedRegion[@"notifyEntryStateOnDisplay"] = @(beaconRegion.notifyEntryStateOnDisplay);
    serializedRegion[@"major"] = beaconRegion.major ?: [NSNull null];
    serializedRegion[@"minor"] = beaconRegion.minor ?: [NSNull null];
    if (@available(iOS 13.0, *)) {
      serializedRegion[@"uuid"] = beaconRegion.UUID;
      NSDictionary *serializedConstraint = @{
        @"uuid": beaconRegion.beaconIdentityConstraint.UUID,
        @"major": beaconRegion.beaconIdentityConstraint.major ?: [NSNull null],
        @"minor": beaconRegion.beaconIdentityConstraint.minor ?: [NSNull null],
      };
      serializedRegion[@"beaconIdentityConstraint"] = serializedConstraint;
    }
  } else {
    serializedRegion[@"type"] = @"unknown";
  }
  return serializedRegion;
}

@end

NS_ASSUME_NONNULL_END
