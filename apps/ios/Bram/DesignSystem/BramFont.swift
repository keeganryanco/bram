import SwiftUI

enum BramFont {
    private enum PostScriptName {
        static let caslonRegular = "ACaslonPro-Regular"
        static let caslonSemibold = "ACaslonPro-Semibold"
        static let caslonBold = "ACaslonPro-Bold"
        static let suisseBook = "SuisseIntlTrial-Book"
        static let suisseRegular = "SuisseIntlTrial-Regular"
        static let suisseMedium = "SuisseIntlTrial-Medium"
        static let suisseSemibold = "SuisseIntlTrial-Semibold"
    }

    static func wordmark(size: CGFloat = 34) -> Font {
        .custom(PostScriptName.caslonSemibold, size: size, relativeTo: .largeTitle)
    }

    static func accent(size: CGFloat = 22) -> Font {
        .custom(PostScriptName.caslonRegular, size: size, relativeTo: .title3)
    }

    static func largeTitle(size: CGFloat = 34) -> Font {
        .custom(PostScriptName.suisseMedium, size: size, relativeTo: .largeTitle)
    }

    static func headline(size: CGFloat = 17) -> Font {
        .custom(PostScriptName.suisseMedium, size: size, relativeTo: .headline)
    }

    static func body(size: CGFloat = 17) -> Font {
        .custom(PostScriptName.suisseRegular, size: size, relativeTo: .body)
    }

    static func callout(size: CGFloat = 15) -> Font {
        .custom(PostScriptName.suisseBook, size: size, relativeTo: .callout)
    }

    static func label(size: CGFloat = 14) -> Font {
        .custom(PostScriptName.suisseMedium, size: size, relativeTo: .subheadline)
    }

    static func button(size: CGFloat = 15) -> Font {
        .custom(PostScriptName.suisseSemibold, size: size, relativeTo: .body)
    }
}
