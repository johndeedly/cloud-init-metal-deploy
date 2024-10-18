#!/usr/bin/env bash

# install firefox
flatpak install --system --assumeyes --noninteractive --or-update flathub org.mozilla.firefox

# ensure default preference directories exists
mkdir -p /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/{policies,defaults/pref}

# https[://]support[.]mozilla[.]org/en-US/kb/customizing-firefox-using-autoconfig
# configure firefox - create autoconfig
tee /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/defaults/pref/autoconfig.js <<EOF
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
EOF

# https[://]github[.]com/arkenfox/user.js/blob/master/user.js
# configure firefox - create configuration file
tee /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/firefox.cfg <<EOF
// IMPORTANT: Start your code on the 2nd line

lockPref("browser.preferences.defaultPerformanceSettings.enabled", false);
lockPref("layers.acceleration.force-enabled", true);
lockPref("layers.offmainthreadcomposition.enabled", true);
lockPref("gfx.webrender.all", true);
lockPref("media.hardware-video-decoding.force-enabled", true);
lockPref("media.hardwaremediakeys.enabled", true);
lockPref("browser.sessionstore.warnOnQuit", false);
lockPref("browser.startup.page", 3);
lockPref("widget.disable-workspace-management", true);
// ui dark mode always enabled
pref("ui.systemUsesDarkTheme", 1);
// do not select a container when opening a new tab
pref("privacy.userContext.newTabContainerOnLeftClick.enabled", false);
// font stuff
pref("font.name.serif.x-western", "Liberation Serif");
pref("font.name.sans-serif.x-western", "Liberation Sans");
pref("font.name.monospace.x-western", "Liberation Mono");
pref("font.minimum-size.x-western", 8);
lockPref("font.default.x-western", "Liberation Serif");
lockPref("font.name-list.emoji", "Noto Color Emoji");
// the user should not be able to display all passwords
lockPref("pref.privacy.disable_button.view_passwords", true);
lockPref("pref.privacy.disable_button.view_passwords_exceptions", true);
// disable advertising in newtab
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
lockPref("browser.newtabpage.activity-stream.showSponsored", false);
lockPref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
lockPref("browser.urlbar.sponsoredTopSites", false);
lockPref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored", false);
lockPref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.topSitesRows", 2);
// disable telemetry
lockPref("app.normandy.api_url", "");
lockPref("app.normandy.enabled", false);
lockPref("app.shield.optoutstudies.enabled", false);
lockPref("breakpad.reportURL", "");
lockPref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
lockPref("browser.crashReports.unsubmittedCheck.enabled", false);
lockPref("browser.newtabpage.activity-stream.feeds.telemetry", false);
lockPref("browser.newtabpage.activity-stream.telemetry", false);
lockPref("browser.ping-centre.telemetry", false);
lockPref("browser.safebrowsing.downloads.remote.enabled", false);
lockPref("browser.safebrowsing.downloads.remote.url", "");
lockPref("browser.tabs.crashReporting.sendReport", false);
lockPref("datareporting.healthreport.uploadEnabled", false);
lockPref("datareporting.policy.dataSubmissionEnabled", false);
lockPref("datareporting.sessions.current.clean", true);
lockPref("devtools.onboarding.telemetry.logged", false);
lockPref("toolkit.coverage.endpoint.base", "");
lockPref("toolkit.coverage.opt-out", true);
lockPref("toolkit.telemetry.archive.enabled", false);
lockPref("toolkit.telemetry.bhrPing.enabled", false);
lockPref("toolkit.telemetry.coverage.opt-out", true);
lockPref("toolkit.telemetry.enabled", false);
lockPref("toolkit.telemetry.firstShutdownPing.enabled", false);
lockPref("toolkit.telemetry.hybridContent.enabled", false);
lockPref("toolkit.telemetry.newProfilePing.enabled", false);
lockPref("toolkit.telemetry.pioneer-new-studies-available", false);
lockPref("toolkit.telemetry.prompted", 2);
lockPref("toolkit.telemetry.rejected", true);
lockPref("toolkit.telemetry.reportingpolicy.firstRun", false);
lockPref("toolkit.telemetry.server", "data:,");
lockPref("toolkit.telemetry.shutdownPingSender.enabled", false);
lockPref("toolkit.telemetry.unified", false);
lockPref("toolkit.telemetry.unifiedIsOptIn", false);
lockPref("toolkit.telemetry.updatePing.enabled", false);
// proxy pre-configuration
// domain names used from https://en.wikipedia.org/wiki/Special-use_domain_name
pref("network.proxy.allow_bypass", false);
pref("network.proxy.failover_direct", false);
pref("network.proxy.no_proxies_on", ".intranet,.internal,.private,.corp,.home,.lan,.local,.locally,.localhost,127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,2001:db8::/32,fc00::/7,fe80::/10");
EOF

# configure firefox - create policies file
tee /var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json <<EOF
{
    "policies": {
        "Extensions": {
            "Install": [
                "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/",
                "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/",
                "https://addons.mozilla.org/firefox/downloads/latest/single-file/",
                "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/",
                "https://addons.mozilla.org/firefox/downloads/latest/forget_me_not/",
                "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/",
                "https://addons.mozilla.org/firefox/downloads/latest/adblock-for-youtube-tm/"
            ],
            "Locked": [
                "adguardadblocker@adguard.com",
                "keepassxc-browser@keepassxc.org",
                "{531906d3-e22f-4a6c-a102-8057b88a1a63}",
                "sponsorBlocker@ajay.app",
                "forget-me-not@lusito.info",
                "{762f9885-5a13-4abd-9c77-433dcd38b8fd}",
                "{0ac04bdb-d698-452f-8048-bcef1a3f4b0d}"
            ]
        }
    }
}
EOF
