/*
 * Backpack - Skyscanner's Design System
 *
 * Copyright 2018-2020 Skyscanner Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "BPKCalendar.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import <FSCalendar/FSCalendar.h>
#import <FSCalendar/FSCalendarCollectionView.h>
#import <FSCalendar/FSCalendarDynamicHeader.h>
#import <FSCalendar/FSCalendarExtensions.h>
#import <FSCalendar/FSCalendarWeekdayView.h>

#import <Backpack/Color.h>
#import <Backpack/Common.h>
#import <Backpack/Font.h>
#import <Backpack/SimpleDate.h>
#import <Backpack/Spacing.h>

#import "BPKCalendarAppearance.h"
#import "BPKCalendarCell.h"
#import "BPKCalendarHeaderCell.h"
#import "BPKCalendarStickyHeader.h"
#import "BPKCalendarYearPill.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSCalendar Extensions
@interface FSCalendar ()

@property(weak, nonatomic) FSCalendarCollectionView *collectionView;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

@end

#pragma mark - BPKCalendar

@interface BPKCalendar () <FSCalendarDelegate, FSCalendarDelegateAppearance, FSCalendarDataSource,
                           UICollectionViewDelegate>

@property(nonatomic, strong, nonnull) FSCalendar *calendarView;
@property(nonatomic, strong, nonnull) FSCalendarWeekdayView *calendarWeekdayView;
@property(nonatomic, strong, nonnull) BPKCalendarYearPill *yearPill;
@property(nonatomic, strong, nonnull) BPKCalendarAppearance *appearance;
@property(nonatomic, strong, nonnull) UIView *bottomBorder;
@property(nonatomic, strong, nonnull) NSCalendar *gregorian;

@property BOOL sameDayRange;

@end

@implementation BPKCalendar

NSString *const CellReuseId = @"cell";
NSString *const HeaderReuseId = @"header";
NSString *const HeaderDateFormat = @"MMMM";

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    BPKAssertMainThread();
    self = [super initWithCoder:coder];
    if (self) {
        // FSCalendar does this internally, but we declare in or public interface that
        // `minDate` and `maxDate` is `nonnull` so we need to ensure **it is not** `nil`.
        self.minDate = [[BPKSimpleDate alloc] initWithYear:1970 month:1 day:1];
        self.maxDate = [[BPKSimpleDate alloc] initWithYear:2099 month:12 day:31];
        [self setup];
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    BPKAssertMainThread();
    self = [super initWithFrame:frame];
    if (self) {
        // FSCalendar does this internally, but we declare in or public interface that
        // `minDate` and `maxDate` is `nonnull` so we need to ensure **it is not** `nil`.
        self.minDate = [[BPKSimpleDate alloc] initWithYear:1970 month:1 day:1];
        self.maxDate = [[BPKSimpleDate alloc] initWithYear:2099 month:12 day:31];
        [self setup];
    }

    return self;
}

- (instancetype)initWithMinDate:(BPKSimpleDate *)minDate maxDate:(BPKSimpleDate *)maxDate {
    BPKAssertMainThread();
    self = [super initWithFrame:CGRectZero];

    if (self) {
        self.minDate = minDate;
        self.maxDate = maxDate;
        [self setup];
    }

    return self;
}

- (void)setup {
    self.gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    self.calendarView = [[FSCalendar alloc] initWithFrame:CGRectZero];
    self.calendarView.scrollDirection = FSCalendarScrollDirectionVertical;
    self.calendarView.scrollEnabled = YES;
    self.calendarView.pagingEnabled = NO;
    self.calendarView.allowsMultipleSelection = self.selectionType != BPKCalendarSelectionSingle;
    self.calendarView.placeholderType = FSCalendarPlaceholderTypeNone;
    self.calendarView.delegate = self;
    self.calendarView.dataSource = self;
    self.calendarView.collectionView.delegate = self;

    NSDictionary<NSAttributedStringKey, id> *weekdayTextAttributes =
        [BPKFont attributesForFontStyle:BPKFontStyleTextSm];

    BPKCalendarAppearance *appearance = [BPKCalendarAppearance fromFSCalendarAppearance:self.calendarView.appearance];
    appearance.headerDateFormat = HeaderDateFormat;
    appearance.headerTitleColor = BPKColor.textPrimaryColor;
    appearance.separators = FSCalendarSeparatorNone;
    appearance.weekdayFont = weekdayTextAttributes[NSFontAttributeName];
    appearance.weekdayTextColor = BPKColor.textPrimaryColor;
    appearance.todayColor = BPKColor.textTertiaryDarkColor;
    appearance.titleTodayColor = BPKColor.textPrimaryColor;
    appearance.titleDefaultColor = BPKColor.textPrimaryColor;
    appearance.selectionColor = self.currentDateSelectedBackgroundColor;
    appearance.titleSelectionColor = self.currentDateSelectedContentColor;
    appearance.headerTitleFontStyle = BPKFontStyleTextLgEmphasized;

    _appearance = appearance;

    Ivar ivar = class_getInstanceVariable(FSCalendar.class, "_appearance");
    object_setIvar(self.calendarView, ivar, self.appearance);

    [self.calendarView registerClass:[BPKCalendarCell class] forCellReuseIdentifier:CellReuseId];
    [self.calendarView.calendarHeaderView.collectionView registerClass:[BPKCalendarHeaderCell class]
                                            forCellWithReuseIdentifier:CellReuseId];

    [self.calendarView.collectionView registerClass:[BPKCalendarStickyHeader class]
                         forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                withReuseIdentifier:HeaderReuseId];

    [self addSubview:self.calendarView];

    self.calendarWeekdayView = [[FSCalendarWeekdayView alloc] initWithFrame:CGRectZero];
    self.calendarWeekdayView.calendar = self.calendarView;
    [self addSubview:self.calendarWeekdayView];

    self.bottomBorder = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomBorder.backgroundColor = BPKColor.lineColor;
    [self addSubview:self.bottomBorder];

    self.yearPill = [[BPKCalendarYearPill alloc] initWithFrame:CGRectZero];
    self.yearPill.hidden = YES;
    [self addSubview:self.yearPill];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // NOTE: This class uses manual layout rather than Auto Layout because it needs to be usable as a Native UI
    // Component from React Native. DON'T attempt to convert it to Auto Layout

    CGRect bounds = self.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat weekdayViewHeight = 6 * BPKSpacingMd;

    self.calendarView.frame =
        CGRectMake(BPKSpacingBase, weekdayViewHeight, width - 2 * BPKSpacingBase, height - weekdayViewHeight);

    self.calendarWeekdayView.frame = CGRectMake(BPKSpacingBase, 0, width - 2 * BPKSpacingBase, weekdayViewHeight);
    self.bottomBorder.frame = CGRectMake(0.0, weekdayViewHeight - 1, width, 1.0);

    CGFloat yearPillWidth = CGRectGetWidth(self.yearPill.bounds);
    CGFloat yearPillHeight = CGRectGetHeight(self.yearPill.bounds);
    self.yearPill.frame =
        CGRectMake(width / 2.0 - yearPillWidth / 2.0, CGRectGetHeight(self.calendarWeekdayView.frame) + BPKSpacingLg,
                   yearPillWidth, yearPillHeight);

    [self.calendarView.collectionViewLayout invalidateLayout];
}

#pragma mark - property getters/setters

- (NSLocale *)locale {
    // This will be nonnull as `FSCalendar` set it
    // to `currentLocale` by default.
    return self.calendarView.locale;
}

- (void)setLocale:(NSLocale *)locale {
    BPKAssertMainThread();
    self.gregorian.locale = locale;
    self.calendarView.locale = locale;
    self.calendarView.firstWeekday = [[locale objectForKey:NSLocaleCalendar] firstWeekday];
    [self.calendarWeekdayView configureAppearance];
}

- (void)setSelectionType:(BPKCalendarSelection)selectionType {
    BPKAssertMainThread();
    _selectionType = selectionType;
    self.calendarView.allowsMultipleSelection = _selectionType != BPKCalendarSelectionSingle;
    for (NSDate *date in self.calendarView.selectedDates) {
        [self.calendarView deselectDate:date];
    }
}

- (NSArray<BPKSimpleDate *> *)selectedDates {
    if (self.sameDayRange) {
        NSArray<NSDate *> *dates =
            [self.calendarView.selectedDates arrayByAddingObject:self.calendarView.selectedDates.firstObject];
        return [BPKSimpleDate simpleDatesFromDates:dates forCalendar:self.gregorian];
    }

    return [BPKSimpleDate simpleDatesFromDates:self.calendarView.selectedDates forCalendar:self.gregorian];
}

- (NSSet<BPKSimpleDate *> *)createDateSet:(NSArray<NSDate *> *)dates {
    NSMutableSet<BPKSimpleDate *> *set = [[NSMutableSet alloc] initWithCapacity:dates.count];

    for (NSDate *date in dates) {
        BPKSimpleDate *simpleDate = [[BPKSimpleDate alloc] initWithDate:date forCalendar:self.gregorian];

        [set addObject:simpleDate];
    }

    return [set copy];
}

- (void)setSelectedDates:(NSArray<BPKSimpleDate *> *)selectedDates {
    BPKAssertMainThread();
    NSSet<BPKSimpleDate *> *previouslySelectedDates = [self createDateSet:self.calendarView.selectedDates];
    NSSet<BPKSimpleDate *> *newSelectedDates = [NSSet setWithArray:selectedDates];

    for (BPKSimpleDate *date in newSelectedDates) {
        if (![previouslySelectedDates containsObject:date]) {
            [self.calendarView selectDate:[date dateForCalendar:self.gregorian]];
        }
    }

    NSMutableSet *toDeselect = [previouslySelectedDates mutableCopy];
    [toDeselect minusSet:newSelectedDates];

    for (BPKSimpleDate *date in toDeselect) {
        [self.calendarView deselectDate:[date dateForCalendar:self.gregorian]];
    }

    if (selectedDates.count == 2 && [selectedDates.firstObject isEqual:selectedDates.lastObject]) {
        self.sameDayRange = YES;
    }
}

#pragma mark - public methods

- (void)reloadData {
    [self.calendarView reloadData];
}

#pragma mark - <FSCalendarDataSource>

- (FSCalendarCell *)calendar:(FSCalendar *)calendar
                 cellForDate:(NSDate *)date
             atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    BPKCalendarCell *cell = [calendar dequeueReusableCellWithIdentifier:CellReuseId
                                                                forDate:date
                                                        atMonthPosition:monthPosition];
    return cell;
}

- (NSDate *)minimumDateForCalendar:(FSCalendar *)calendar {
    return [self.minDate dateForCalendar:self.gregorian];
}

- (NSDate *)maximumDateForCalendar:(FSCalendar *)calendar {
    return [self.maxDate dateForCalendar:self.gregorian];
}

- (void)setDateSelectedBackgroundColor:(UIColor *_Nullable)dateSelectedBackgroundColor {
    if (dateSelectedBackgroundColor != _dateSelectedBackgroundColor) {
        _dateSelectedBackgroundColor = dateSelectedBackgroundColor;
        self.appearance.selectionColor = self.currentDateSelectedBackgroundColor;
        [self.calendarView.collectionView reloadData];
    }
}

- (void)setDateSelectedContentColor:(UIColor *_Nullable)dateSelectedContentColor {
    if (dateSelectedContentColor != _dateSelectedContentColor) {
        _dateSelectedContentColor = dateSelectedContentColor;
        self.appearance.titleSelectionColor = self.currentDateSelectedContentColor;
        [self.calendarView.collectionView reloadData];
    }
}

#pragma mark - <FSCalendarDelegate>

- (BOOL)calendar:(FSCalendar *)calendar
    shouldSelectDate:(NSDate *)date
     atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    BOOL enabled = [self isDateEnabled:date];

    if (!enabled) {
        return NO;
    }

    if (self.sameDayRange) {
        self.sameDayRange = NO;
    }

    if (self.selectionType == BPKCalendarSelectionRange) {
        if (calendar.selectedDates.count >= 2) {
            for (NSDate *date in calendar.selectedDates) {
                [calendar deselectDate:date];
            }
        }

        for (NSDate *selectedDate in calendar.selectedDates) {
            if ([date compare:selectedDate] == NSOrderedAscending) {
                [calendar deselectDate:selectedDate];
            }
        }
    }

    return YES;
}

- (BOOL)calendar:(FSCalendar *)calendar
    shouldDeselectDate:(NSDate *)date
       atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    if (self.sameDayRange || self.selectionType != BPKCalendarSelectionRange) {
        self.sameDayRange = NO;
        return YES;
    } else {
        self.sameDayRange = calendar.selectedDates.count < 2;
        for (NSDate *actualDate in calendar.selectedDates) {
            if (![date isEqualToDate:actualDate]) {
                [calendar deselectDate:actualDate];
            }
        }
        [self calendar:self.calendarView didSelectDate:date atMonthPosition:monthPosition];
        return NO;
    }
}

- (void)calendar:(FSCalendar *)calendar
      didSelectDate:(NSDate *)date
    atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    [self configureVisibleCells];
    [self.delegate calendar:self didChangeDateSelection:self.selectedDates];

    [self invalidateVisibleCellsIfNeeded];
}

- (void)calendar:(FSCalendar *)calendar
    didDeselectDate:(NSDate *)date
    atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    [self configureVisibleCells];
    [self.delegate calendar:self didChangeDateSelection:self.selectedDates];

    [self invalidateVisibleCellsIfNeeded];
}

- (void)calendar:(FSCalendar *)calendar
    willDisplayCell:(FSCalendarCell *)cell
            forDate:(NSDate *)date
    atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    NSDateComponents *components = [self.calendarView.gregorian components:NSCalendarUnitYear | NSCalendarUnitMonth
                                                                  fromDate:date];
    NSDateComponents *todayComponents = [self.calendarView.gregorian components:NSCalendarUnitYear
                                                                       fromDate:NSDate.date];
    BOOL isDateOutsideCurrentYear = components.year != todayComponents.year;
    BOOL notJanuaryOrDecember = components.month != 1 && components.month != 12;

    if (monthPosition == FSCalendarMonthPositionCurrent && isDateOutsideCurrentYear && notJanuaryOrDecember) {
        self.yearPill.hidden = NO;
        self.yearPill.year = [NSNumber numberWithInteger:components.year];
    } else if (notJanuaryOrDecember) {
        self.yearPill.hidden = YES;
    }

    [self configureCell:cell forDate:date atMonthPosition:monthPosition];
}

#pragma mark - <FSCalendarDelegateAppearance>

- (nullable UIColor *)calendar:(FSCalendar *)calendar
                    appearance:(FSCalendarAppearance *)appearance
       fillDefaultColorForDate:(NSDate *)date {
    if ([self isDateEnabled:date]) {
        if ([self.delegate respondsToSelector:@selector(calendar:cellStyleForDate:)]) {
            BPKSimpleDate *simpleDate = [[BPKSimpleDate alloc] initWithDate:date forCalendar:self.gregorian];

            BPKCalendarDateCellStyle style = [self.delegate calendar:self cellStyleForDate:simpleDate];

            // For the custom style we fallback to calling
            // `calendar:fillColorForDate:` below
            if (style != BPKCalendarDateCellStyleCustom) {
                return [[self class] fillColorForDateStyle:style appearance:appearance];
            }
        }

        if ([self.delegate respondsToSelector:@selector(calendar:fillColorForDate:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            return [self.delegate calendar:self fillColorForDate:date];
#pragma clang diagnoastic pop
        }
    }

    if ([self isDateInToday:date]) {
        return [UIColor clearColor];
    }

    return [[self class] fillColorForDateStyle:BPKCalendarDateCellStyleNormal appearance:appearance];
}

- (nullable UIColor *)calendar:(FSCalendar *)calendar
                    appearance:(FSCalendarAppearance *)appearance
      titleDefaultColorForDate:(nonnull NSDate *)date {

    if ([self isDateEnabled:date]) {
        if ([self.delegate respondsToSelector:@selector(calendar:cellStyleForDate:)]) {
            BPKSimpleDate *simpleDate = [[BPKSimpleDate alloc] initWithDate:date forCalendar:self.gregorian];

            BPKCalendarDateCellStyle style = [self.delegate calendar:self cellStyleForDate:simpleDate];

            // For the custom style we fallback to calling
            // `calendar:titleColorForDate:` below
            if (style != BPKCalendarDateCellStyleCustom) {
                return [[self class] titleColorForDateStyle:style appearance:appearance];
            }
        }

        if ([self.delegate respondsToSelector:@selector(calendar:titleColorForDate:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            return [self.delegate calendar:self titleColorForDate:date];
#pragma clang diagnoastic pop
        }


        return self.appearance.titleDefaultColor;
    }

    return [BPKColor dynamicColorWithLightVariant:BPKColor.skyGrayTint06 darkVariant:BPKColor.textSecondaryDarkColor];
}

- (nullable UIColor *)calendar:(FSCalendar *)calendar
                    appearance:(FSCalendarAppearance *)appearance
     borderDefaultColorForDate:(NSDate *)date {
    if ([self isDateInToday:date]) {
        return appearance.todayColor;
    }
    return appearance.borderDefaultColor;
}

#pragma mark - <UICollectionViewDelegate>

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([self.delegate respondsToSelector:@selector(calendar:didScroll:)]) {
        [self.delegate calendar:self didScroll:scrollView.contentOffset];
    }
    [self.calendarView scrollViewDidScroll:scrollView];
}

#pragma mark - private

- (CGPoint)contentOffset {
    return self.calendarView.collectionView.contentOffset;
}

- (UIEdgeInsets)contentInset {
    return self.calendarView.collectionView.contentInset;
}

- (CGSize)contentSize {
    return self.calendarView.collectionView.contentSize;
}

- (BOOL)isDecelerating {
    return self.calendarView.collectionView.isDecelerating;
}

- (BOOL)isDragging {
    return self.calendarView.collectionView.isDragging;
}

- (BOOL)isTracking {
    return self.calendarView.collectionView.isTracking;
}

- (void)configureVisibleCells {
    [self.calendarView.visibleCells
        enumerateObjectsUsingBlock:^(__kindof FSCalendarCell *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
          NSDate *date = [self.calendarView dateForCell:obj];
          FSCalendarMonthPosition position = [self.calendarView monthPositionForCell:obj];
          [self configureCell:obj forDate:date atMonthPosition:position];
        }];
}

- (void)configureCell:(FSCalendarCell *)cell
              forDate:(NSDate *)date
      atMonthPosition:(FSCalendarMonthPosition)monthPosition {
    NSArray<NSDate *> *selectedDates =
        [self.calendarView.selectedDates sortedArrayUsingComparator:^NSComparisonResult(NSDate *a, NSDate *b) {
          return [a compare:b];
        }];
    BPKCalendarCell *calendarCell = (BPKCalendarCell *)cell;

    // Configure selection layer
    if (monthPosition == FSCalendarMonthPositionCurrent) {
        SelectionType selectionType = SelectionTypeNone;
        RowType rowType = RowTypeMiddle;

        if (selectedDates.count > 1 && self.selectionType == BPKCalendarSelectionRange) {
            NSDate *minDate = [selectedDates firstObject];
            NSDate *maxDate = [selectedDates lastObject];
            BOOL dateInsideRange = [BPKCalendar date:date isBetweenDate:minDate andDate:maxDate];
            if (dateInsideRange) {
                BOOL isMinDate = [date isEqualToDate:minDate];
                BOOL isMaxDate = [date isEqualToDate:maxDate];
                NSCalendar *gregorian = self.calendarView.gregorian;
                NSDate *firstWeekday = [gregorian fs_firstDayOfWeek:date];
                NSDate *lastWeekday = [gregorian fs_lastDayOfWeek:date];
                NSDate *firstDayOfMonth = [gregorian fs_firstDayOfMonth:date];
                NSDate *lastDayOfMonth = [gregorian fs_lastDayOfMonth:date];
                BOOL isRowStart = [gregorian isDate:date inSameDayAsDate:firstWeekday] ||
                                  [gregorian isDate:date inSameDayAsDate:firstDayOfMonth];
                BOOL isRowEnd = [gregorian isDate:date inSameDayAsDate:lastWeekday] ||
                                [gregorian isDate:date inSameDayAsDate:lastDayOfMonth];

                if (isRowStart && isRowEnd) {
                    rowType = RowTypeBoth;
                } else if (isRowStart) {
                    rowType = RowTypeStart;
                } else if (isRowEnd) {
                    rowType = RowTypeEnd;
                }

                if (isMinDate) {
                    selectionType = SelectionTypeLeadingBorder;
                } else if (isMaxDate) {
                    selectionType = SelectionTypeTrailingBorder;
                } else {
                    selectionType = SelectionTypeMiddle;
                }
            }
        } else if ([selectedDates containsObject:date]) {
            selectionType = self.sameDayRange ? SelectionTypeSameDay : SelectionTypeSingle;
        }

        calendarCell.selectionType = selectionType;
        calendarCell.rowType = rowType;
        calendarCell.accessibilityLabel = [self formattedDate:date];

        if ([self isDateEnabled:date]) {
            calendarCell.isAccessibilityElement = YES;
            calendarCell.accessibilityElementsHidden = NO;
        } else {
            // Hides the element from screen-readers to save swiping forever!
            // Not this only takes effect after the cells have been invalidated.
            calendarCell.isAccessibilityElement = NO;
            calendarCell.accessibilityElementsHidden = YES;
        }

        calendarCell.accessibilityTraits = UIAccessibilityTraitButton;
        if (selectionType == SelectionTypeSingle || selectionType == SelectionTypeSameDay ||
            selectionType == SelectionTypeLeadingBorder || selectionType == SelectionTypeTrailingBorder) {
            calendarCell.accessibilityTraits = calendarCell.accessibilityTraits | UIAccessibilityTraitSelected;
        }
    }
}

+ (UIColor *)fillColorForDateStyle:(BPKCalendarDateCellStyle)style
                        appearance:(FSCalendarAppearance *)appearance {
    switch (style) {
        case BPKCalendarDateCellStyleNormal:
            return appearance.borderDefaultColor;
        case BPKCalendarDateCellStylePositive:
            return BPKColor.glencoe;
        case BPKCalendarDateCellStyleNeutral:
            return BPKColor.erfoud;
        case BPKCalendarDateCellStyleNegative:
            return BPKColor.hillier;
        case BPKCalendarDateCellStyleCustom:
            NSAssert(NO, @"fillColorForDateStyle:appearance: should not be called with the custom cell style. For a custom cell style, we should call calendar:fillColorForDate: on the delegate instead.");
            return BPKColor.clear;
        default:
            NSAssert(NO, @"Unknown value for `BPKCalendarDateCellStyle`: %ld", style);
            return BPKColor.clear;
    }
}

+ (UIColor *)titleColorForDateStyle:(BPKCalendarDateCellStyle)style
                         appearance:(FSCalendarAppearance *)appearance {
    switch (style) {
        case BPKCalendarDateCellStyleNormal:
            return appearance.titleDefaultColor;

        // HERE BE DRAGONS: Explicit fallthrough
        case BPKCalendarDateCellStylePositive:
        case BPKCalendarDateCellStyleNeutral:
        case BPKCalendarDateCellStyleNegative:
            return BPKColor.skyGray;

        case BPKCalendarDateCellStyleCustom:
            NSAssert(NO, @"fillColorForDateStyle:appearance: should not be called with the custom cell style. For a custom cell style, we should call calendar:titleColorForDate: on the delegate instead.");
            return BPKColor.clear;

        default:
            NSAssert(NO, @"Unknown value for `BPKCalendarDateCellStyle`: %ld", style);
            return BPKColor.textPrimaryColor;
    }
}

#pragma mark - helpers

- (void)invalidateVisibleCellsIfNeeded {
    // If the consumer is dynamically disabling dates, we will need to invalidate all cells to ensure that the change is
    // visually reflected.
    if ([self.delegate respondsToSelector:@selector(calendar:isDateEnabled:)]) {
        // This works, but it prevents the selection animation from working 😞
        NSArray<NSIndexPath *> *indexPathsForVisibleItems =
            [self.calendarView.collectionView indexPathsForVisibleItems];
        [self.calendarView.collectionView reloadItemsAtIndexPaths:indexPathsForVisibleItems];
    }
}

- (BOOL)isDateEnabled:(NSDate *)date {
    NSDate *minDate = [self.minDate dateForCalendar:self.gregorian];
    NSDate *maxDate = [self.maxDate dateForCalendar:self.gregorian];

    BOOL dateFallsBetweenMinAndMaxDates = [BPKCalendar date:date isBetweenDate:minDate andDate:maxDate];

    // If the date is outside min and max dates, then it should definitely be disabled.
    if (!dateFallsBetweenMinAndMaxDates) {
        return false;
    }

    // If the consumer has implemented `isDateEnabled` then we should respect that
    if ([self.delegate respondsToSelector:@selector(calendar:isDateEnabled:)]) {
        return [self.delegate calendar:self isDateEnabled:date];
    }

    // Gonna return true, because in the words of Sia, I'm still here...
    return true;
}

- (NSString *)formattedDate:(NSDate *)date {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.locale = self.locale;
    dateFormatter.dateStyle = NSDateFormatterLongStyle;
    return [dateFormatter stringFromDate:date];
}

- (BOOL)isDateInToday:(NSDate *)date {
    return [self.calendarView.gregorian isDateInToday:date];
}

+ (BOOL)date:(NSDate *)date isBetweenDate:(NSDate *)beginDate andDate:(NSDate *)endDate {
    if ([date compare:beginDate] == NSOrderedAscending)
        return NO;

    if ([date compare:endDate] == NSOrderedDescending)
        return NO;

    return YES;
}

#pragma mark -

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [super respondsToSelector:aSelector] || [self.calendarView respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    if ([self.calendarView respondsToSelector:selector]) {
        return self.calendarView;
    }
    return [super forwardingTargetForSelector:selector];
}

#pragma mark - Getters

- (UIColor *)currentDateSelectedBackgroundColor {
    return self.dateSelectedBackgroundColor != nil ? self.dateSelectedBackgroundColor : BPKColor.skyBlue;
}

- (UIColor *)currentDateSelectedContentColor {
    return self.dateSelectedContentColor != nil ? self.dateSelectedContentColor : BPKColor.white;
}

@end
NS_ASSUME_NONNULL_END
