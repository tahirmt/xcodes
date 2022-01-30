//
//  HTTPCookieStorage+Fastlane.swift
//  
//
//  Created by Mahmood Tahir on 2022-01-25.
//

import Foundation
import ShellOut

enum HTTPCookieStorageLoadError: Error {
    case noScript
    case couldNotConvertStringToData
}

extension HTTPCookieStorage {
    public func loadFastlaneCookies(from path: String = "~/.fastlane/spaceship", for email: String? = nil) throws {

        guard let scriptPath = Bundle.module.path(forResource: "load_cookies", ofType: "rb", inDirectory: "Resources") else {
            print("can't find load_cookies.rb")
            throw HTTPCookieStorageLoadError.noScript
        }

        var command = "ruby \(scriptPath)"

        if let email = email {
            command += " \(email)"
        }

        try shellOut(to: command)

        let cookiesString = try shellOut(to: "[ -e cookies.json ] && cat cookies.json")

        // remove cookies file
        try shellOut(to: "[ -e cookies.json ] && rm cookies.json")

        guard let cookiesData = cookiesString.data(using: .utf8) else {
            throw HTTPCookieStorageLoadError.couldNotConvertStringToData
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let cookies = try decoder.decode([Cookie].self, from: cookiesData)

        let httpCookies = cookies.compactMap { cookie -> HTTPCookie? in
            // apple.com cookies are supposed to be for all apple.com requests
            func convertAppleDomain(_ domain: String?) -> String? {
                guard domain == "apple.com" else { return domain }
                return ".apple.com"
            }

            let properties: [HTTPCookiePropertyKey: Any] =  [
                .name: cookie.name,
                .value: cookie.value,
                .domain: convertAppleDomain(cookie.domain),
                .path: cookie.path,
                .expires: cookie.expires,
                .secure: cookie.secure.flatMap { String($0) },
                .maximumAge: cookie.maxAge.flatMap { String($0) },
                .originURL: cookie.origin,
            ].compactMapValues { $0 }

            return HTTPCookie(properties: properties)
        }

        print("loaded \(httpCookies.count) cookies")

        cookieAcceptPolicy = .always
        httpCookies.forEach {
            setCookie($0)
        }
    }
}

private struct Cookie: Decodable {
    let name: String?
    let value: String?
    let domain: String?
    let path: String?
    let expires: String?
    let secure: Bool?
    let maxAge: UInt?
    let origin: String?
}
