import Foundation

/// Centralized configuration constants and placeholders for Customs Toolkit Version 0.1.
public enum AppConfig {
    
    // MARK: - Application Metadata
    public static let appName = "Customs Toolkit"
    public static let appNameArabic = "أدوات التخليص الجمركي"
    public static let appVersion = "0.2.0"
    public static let buildNumber = "2"
    
    // MARK: - Customs Tariff Metadata Configuration
    public static let tariffCountry = "Oman"
    public static let tariffYear = 2026
    public static let tariffDatasetResourceName = "oman_tariff_2026"
    public static let omanCustomsTariffSource = "Official Oman Customs Tariff 2026"

    /// Official Oman Customs public calculator and HS requirements portals.
    public static let omanDutyCalculatorURL = "https://www.customs.gov.om/esw/jsf/secure/esw/common/DutyCalculator.xhtml"
    public static let omanHSRequirementsURL = "https://www.customs.gov.om/esw/jsf/secure/esw/common/PublicHSCodeSearch.xhtml"
    
    /// Maximum supported local HS code digit length (Oman local codes can be 12 digits or more).
    public static let maxHSCodeLength: Int = 16
    
    // MARK: - Gold Price Source Configuration
    /// The official trusted Gold Price portal for Oman customs workflow.
    public static let trustedGoldPriceURL = "https://www.gold-price-today.com/oman/"
    
    // MARK: - Calculator Business Rules Configuration
    public enum Calculator {
        /// Standard VAT rate (5% in Oman / GCC Customs declarations).
        public static let defaultVatRate: Decimal = Decimal(string: "0.05")!
        
        /// Confirmed fixed adjustment for the "Duty + VAT" workflow.
        /// Verified against the provided company Excel workbook (Sheet2 / Sheet3).
        public static let dutyAndVatAdjustment: Decimal = Decimal(string: "97.566")!
        
        /// Confirmed fixed adjustment for the "VAT Only" workflow.
        /// Business rule supplied by the user: subtract 200.000 OMR.
        public static let vatOnlyAdjustment: Decimal = Decimal(string: "200.000")!
        
        /// Default currency code for base calculations.
        public static let baseCurrencyCode = "OMR"
    }
}
