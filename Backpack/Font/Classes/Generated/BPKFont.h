// clang-format off
/*
 * Backpack - Skyscanner's Design System
 *
 * Copyright 2018-2019 Skyscanner Ltd
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
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BPKFontStyle) {

    /// :nodoc:
    BPKFontStyleTextBase = 0,
    /// :nodoc:
    BPKFontStyleTextBaseEmphasized = 1,
    /// :nodoc:
    BPKFontStyleTextCaps = 11,
    /// :nodoc:
    BPKFontStyleTextCapsEmphasized = 12,
    /// :nodoc:
    BPKFontStyleTextLg = 2,
    /// :nodoc:
    BPKFontStyleTextLgEmphasized = 3,
    /// :nodoc:
    BPKFontStyleTextSm = 4,
    /// :nodoc:
    BPKFontStyleTextSmEmphasized = 5,
    /// :nodoc:
    BPKFontStyleTextXl = 6,
    /// :nodoc:
    BPKFontStyleTextXlEmphasized = 7,
    /// :nodoc:
    BPKFontStyleTextXlHeavy = 10,
    /// :nodoc:
    BPKFontStyleTextXs = 8,
    /// :nodoc:
    BPKFontStyleTextXsEmphasized = 9,
    /// :nodoc:
    BPKFontStyleTextXxl = 13,
    /// :nodoc:
    BPKFontStyleTextXxlEmphasized = 14,
    /// :nodoc:
    BPKFontStyleTextXxlHeavy = 15,
    /// :nodoc:
    BPKFontStyleTextXxxl = 16,
    /// :nodoc:
    BPKFontStyleTextXxxlEmphasized = 17,
    /// :nodoc:
    BPKFontStyleTextXxxlHeavy = 18,
};

NS_ASSUME_NONNULL_BEGIN
@class UIFont;
@class BPKFontManager;
@protocol BPKFontDefinitionProtocol;
/**
 * BPKFont is the entry point for the Backpack typography stack. It expose the
 * supported text styles as static methods.
 *
*/
NS_SWIFT_NAME(Font) @interface BPKFont: NSObject

/**
 * Create a dictionary of attributes for a specific text styles. This is some times useful
 * when building custom attributed strings is required.
 *
 * @param fontStyle The desired fontStyle.
 * @return A dictionary of attributes describing the specified style.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (NSDictionary<NSAttributedStringKey, id> *)attributesForFontStyle:(BPKFontStyle)fontStyle NS_SWIFT_NAME(makeAttributes(fontStyle:));

/**
 * Create a dictionary of attributes for a specific text styles. This is some times useful
 * when building custom attributed strings is required.
 *
 * @param fontStyle The desired fontStyle.
 * @param fontManager The fontManager instance to use. By default this is `[BPKFontManager sharedInstance]`.
 * @return A dictionary of attributes describing the specified style.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (NSDictionary<NSAttributedStringKey, id> *)attributesForFontStyle:(BPKFontStyle)fontStyle fontManager:(BPKFontManager *)fontManager NS_SWIFT_NAME(makeAttributes(fontStyle:fontManager:));

/**
 * Create a dictionary of attributes for a specific text styles. This is some times useful
 * when building custom attributed strings is required.
 *
 * @param fontStyle The desired fontStyle.
 * @param customAttributes Additional attributes to include in the result. Attributes that would break the Backpack type
 *  rendering are ignored.
 * @return A dictionary of attributes describing the specified style and custom attributes.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (NSDictionary<NSAttributedStringKey, id> *)attributesForFontStyle:(BPKFontStyle)fontStyle
                                               withCustomAttributes:(NSDictionary<NSAttributedStringKey, id> *)customAttributes NS_SWIFT_NAME(makeAttributes(fontStyle:customAttributes:));

/**
 * Create an attributed string with a specified fontStyle and content. The default Backpack
 * text color will be used.
 *
 * @param fontStyle The desired fontStyle.
 * @param content The content of the attributedString.
 * @return An attributed string with the specified styles.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (NSAttributedString *)attributedStringWithFontStyle:(BPKFontStyle)fontStyle content:(NSString *)content NS_SWIFT_NAME(makeAttributedString(fontStyle:content:));

/**
 * Create an attributed string with a specified fontStyle, content, and text color.
 *
 * @param fontStyle The desired fontStyle.
 * @param content The content of the attributedString.
 * @param textColor The text color to use.
 * @return An attributed string with the specified styles.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (NSAttributedString *)attributedStringWithFontStyle:(BPKFontStyle)fontStyle content:(NSString *)content textColor:(UIColor *)textColor NS_SWIFT_NAME(makeAttributedString(fontStyle:content:textColor:));

/**
 * Set the fontfaces to use globally.
 *
 * @param fontDefinition The new font definition to use when resolving fontface names.
*/
+ (void)setFontDefinition:(id<BPKFontDefinitionProtocol>_Nullable)fontDefinition;

/**
 * Create a `UIFont` instance for a specific text style.
 *
 *
 * @param fontStyle The desired fontStyle.
 * @return An instance of `UIFont` for the specificed style.
 *
 * @warning Prefer using `BPKLabel`, `BPKTextField`, or `BPKTextView` for rendering text when possible.
 */
+ (UIFont *)fontForFontStyle:(BPKFontStyle)fontStyle NS_SWIFT_NAME(makeFont(fontStyle:));

@end

NS_ASSUME_NONNULL_END
// clang-format on
