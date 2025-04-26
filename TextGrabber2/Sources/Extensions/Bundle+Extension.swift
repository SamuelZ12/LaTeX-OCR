import Foundation

extension Bundle {
  var bundleName: String? {
    infoDictionary?[kCFBundleNameKey as String] as? String
  }

  var shortVersionString: String {
    guard let version = infoDictionary?["CFBundleShortVersionString"] as? String else {
      Logger.assertFail("Missing CFBundleShortVersionString in bundle \(self)")
      return "1.0.0"
    }

    return version
  }
}
