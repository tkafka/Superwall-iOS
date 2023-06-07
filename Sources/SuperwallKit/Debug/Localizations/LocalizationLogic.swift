//
//  LocalizationLogic.swift
//  Superwall
//
//  Created by Yusuf Tör on 07/03/2022.
//

import Foundation

enum LocalizationLogic {
  static func getSortedLocalizations(
    forLocales localeIds: [String],
    popularLocales: [String]
  ) -> [LocalizationOption] {
    var localizations: [LocalizationOption] = []
    let currentLocale = Locale.autoupdatingCurrent

    for localeId in localeIds {
      // Get language, skip the ones without localizedLanguage (may be a result of missing entries in iOS beta)
      guard let localizedLanguage = currentLocale.localizedString(
        forLanguageCode: localeId
			) else {
				continue
			}

      // Get country
      let locale = Locale(identifier: localeId)
      let localeIdComponents = localeId.split(separator: "_")
      var country: String?

      if let regionCode = locale.regionCode {
        country = currentLocale.localizedString(forRegionCode: regionCode)
      } else if let countryCode = localeIdComponents.last,
        localeIdComponents.count > 1 {
        country = currentLocale.localizedString(forRegionCode: String(countryCode))
      }

      let localizationOption = LocalizationOption(
        language: localizedLanguage,
        country: country,
        locale: localeId,
        popularLocales: popularLocales
      )
      localizations.append(localizationOption)
    }

    // Sort in ascending manner
    localizations.sort {
      $0.sortDescription < $1.sortDescription
    }
    return localizations
  }

  static func getGroupings(
    for localizationOptions: [LocalizationOption]
  ) -> [LocalizationGrouping] {
    var groupings: [LocalizationGrouping] = []

    for localizationOption in localizationOptions {
      if let currentGrouping = groupings.last {
        if currentGrouping.title != localizationOption.sectionTitle {
          let grouping = LocalizationGrouping(
            localizations: [],
            title: localizationOption.sectionTitle
          )
          groupings.append(grouping)
        }
      } else {
        let grouping = LocalizationGrouping(
          localizations: [],
          title: localizationOption.sectionTitle
        )
        groupings.append(grouping)
      }

      groupings[groupings.count - 1].localizations.append(localizationOption)
    }

    return groupings
  }
}
