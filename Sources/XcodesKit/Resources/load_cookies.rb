require 'bundler/inline'
require 'json'
require "pathname"

gemfile do
    source 'https://rubygems.org'

    gem 'http-cookie'
    gem 'fastlane'
end

email = ARGV[0] if ARGV.count > 0
path = ARGV[1] if ARGV.count > 0
path = './cookies.json' if path.nil?

FASTLANE_COOKIE_ROOT = "#{ENV["HOME"]}/.fastlane/spaceship"

def has_refreshable_cookie(cookie_jar)
    cookies = cookie_jar.cookies
    valid_cookie = cookies.select { |cookie| 
        cookie.domain && cookie.domain == "idmsa.apple.com" && cookie.expires && (cookie.expires.to_time.to_i - Time.now.to_i) > 0
    }

    valid_cookie.empty? ? false : true
end

def fastlane_cookie_directories
    Pathname.new(FASTLANE_COOKIE_ROOT).children.select { |c| c.directory? }
end

def load_cookies_from_directory_into_jar(directory, cookie_jar)
    Pathname.new(directory).children.select { |c| c.file? }.each do |file|
        # Cookie file
        filename = file.to_s
        cookie_jar.load(filename) if File.exist?(filename)
    end
end

def refresh_fastlane_cookie_if_needed
    refreshed_email = nil

    fastlane_cookie_directories.each do |dir|
        # get directory name. This will be the mail address of the apple user
        email = dir.basename.to_s
        cookie_jar = HTTP::CookieJar.new

        load_cookies_from_directory_into_jar(dir, cookie_jar)

        if has_refreshable_cookie(cookie_jar)
            puts "Refreshing cookie for #{email}"

            # Refresh the cookie
            `fastlane spaceauth -u #{email}`
            refreshed_email = email
        end
    end

    return refreshed_email
end

def convert_cookies_from_jar_into_json(cookie_jar)
    cookie_jar.cookies.map { |cookie|
        {
            :name => cookie.name,
            :value => cookie.value,
            :domain => cookie.domain,
            :path => cookie.path,
            :expires => cookie.expires,
            :expires_at => cookie.expires_at,
            :secure => cookie.secure,
            :httponly => cookie.httponly,
            :session => cookie.session,
            :created_at => cookie.created_at,
            :origin => cookie.origin,
            :max_age => cookie.max_age,
            :for_domain => cookie.for_domain,
        }
    }.to_json
end

def save_cookies_to_file(filename, cookie_jar)
    File.open(filename, 'w') do |f|
        f.write(convert_cookies_from_jar_into_json(cookie_jar))
    end
end

email = refresh_fastlane_cookie_if_needed

if email != nil
    # Load cookies for the refreshed email
    jar = HTTP::CookieJar.new
    load_cookies_from_directory_into_jar(FASTLANE_COOKIE_ROOT + "/#{email}", jar)

    # Save cookies to file
    save_cookies_to_file(path, jar)
else
    puts "No cookies refreshed. Please run `fastlane spaceauth` to refresh your cookies."
end
