//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation

extension Result where Success == Void {
    public static func success() -> Self { .success(()) }
}
