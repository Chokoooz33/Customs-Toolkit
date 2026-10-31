import XCTest
@testable import CustomsToolkit

final class AirCargoTrackingTests: XCTestCase {
    func testAWBNormalizationAndFormatting() {
        XCTAssertEqual(AWBNormalizer.normalized("176-12345678"), "17612345678")
        XCTAssertEqual(AWBNormalizer.normalized("١٧٦ ١٢٣٤٥٦٧٨"), "17612345678")
        XCTAssertEqual(AWBNormalizer.formatted("17612345678"), "176-12345678")
        XCTAssertTrue(AWBNormalizer.isValidLength("176-12345678"))
        XCTAssertFalse(AWBNormalizer.isValidLength("176-1234"))
    }

    func testKnownAirlinePrefix() {
        let source = AirlineDirectory.source(forAWB: "176-12345678")
        XCTAssertEqual(source?.prefix, "176")
        XCTAssertEqual(source?.name, "Emirates SkyCargo")
    }

    func testOmanAirLiveTrackingURLIsPreparedWithPrefixAndSerial() {
        let url = AirlineDirectory.liveTrackingURL(forAWB: "910-18733654")
        let absolute = url?.absoluteString ?? ""
        XCTAssertTrue(absolute.contains("omanair.smartkargo.com/FrmAWBTracking.aspx"))
        XCTAssertTrue(absolute.contains("AWBNo=18733654"))
        XCTAssertTrue(absolute.contains("AWBPrefix=910"))
    }

    func testAirlineTextParserExtractsGenericLiveFields() {
        let text = """
        AWB 910-18733654
        Flight Number WY123
        Origin DXB
        Destination MCT
        Departure 24 AUG 08:45
        Arrival 24 AUG 10:05
        Pieces 12
        Gross Weight 286 KG
        Status Arrived
        Last Event Arrived at Destination
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Oman Air Cargo",
            airlinePrefix: "910",
            sourceURL: URL(string: "https://cargo.omanair.com")!
        )

        XCTAssertEqual(snapshot?.flightNumber, "WY123")
        XCTAssertEqual(snapshot?.origin, "DXB")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 12)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "286"))
    }

    func testGenericAirlineParserKeepsOnlyRealRecentEventsNewestFirst() {
        let text = """
        AWB 607-12345678
        Flight Number EY123
        Origin AUH
        Destination MCT
        Status In Transit
        25 AUG 2026 08:10 Accepted at AUH
        25 AUG 2026 10:30 Departed from AUH
        25 AUG 2026 11:40 Arrived at MCT
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Etihad Cargo",
            airlinePrefix: "607",
            sourceURL: URL(string: "https://www.etihadcargo.com")!
        )

        XCTAssertEqual(snapshot?.recentEvents?.count, 3)
        XCTAssertEqual(snapshot?.recentEvents?[0].code, "ARR")
        XCTAssertEqual(snapshot?.recentEvents?[0].location, "MCT")
        XCTAssertEqual(snapshot?.recentEvents?[1].code, "DEP")
        XCTAssertEqual(snapshot?.recentEvents?[2].code, "RCS")
    }

    /// Regression fixture transcribed from the user's verified Oman Air SmartKargo result for
    /// 910-18733654. This is not fabricated production data; it is test-only source text.
    func testOmanAirSmartKargoFixtureForVerifiedAWB() {
        let text = """
        Track Air Waybill
        910-18733654 Arrived at MCT
        LHR LONDON HEATHROW ACCEPTED 15/08/2026 16:02 14 P / 111.50 Kgs
        DEPARTED WY104 16/08/2026 08:25 14 P / 111.50 Kgs
        MCT Muscat International Airport ARRIVED WY104 16/08/2026 18:45 14 P / 111.50 Kgs
        AWB : 910-18733654 (LHR-MCT) 14 P / 111.50 Kgs
        Last Activity Arrived at MCT 14 P / 111.50 Kgs
        Booking and Acceptance Information
        Status Station Dest Pcs Weight Flight# Event Date-Time
        Booked [C] LHR MCT 14 111.50 Kgs WY102 15/08/2026 07/08/2026 16:03
        Accepted LHR MCT 14 111.50 Kgs 15/08/2026 16:02
        Arrived LHR MCT 14 111.50 Kgs WY104 16/08/2026 ETD: 08:25 ETA: 18:45 16/08/2026 17:27
        Status History
        LHR Departed 14 111.50 Kgs WY104 16/08/2026 08:25 LHR MCT PMC0349WY (14)
        MCT Arrived 14 111.50 Kgs WY104 16/08/2026 18:45 LHR MCT AWB received from a given flight (14)
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Oman Air Cargo",
            airlinePrefix: "910",
            sourceURL: URL(string: "https://omanair.smartkargo.com/FrmAWBTracking.aspx")!
        )

        XCTAssertEqual(snapshot?.flightNumber, "WY104")
        XCTAssertEqual(snapshot?.origin, "LHR")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 14)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "111.50"))
        XCTAssertEqual(snapshot?.departure, "16/08/2026 08:25")
        XCTAssertEqual(snapshot?.arrival, "16/08/2026 18:45")
        XCTAssertEqual(snapshot?.status, "Arrived at MCT")
        XCTAssertEqual(snapshot?.recentEvents?.count, 3)
        XCTAssertEqual(snapshot?.recentEvents?[0].code, "ARR")
        XCTAssertEqual(snapshot?.recentEvents?[0].location, "MCT")
        XCTAssertEqual(snapshot?.recentEvents?[1].code, "DEP")
        XCTAssertEqual(snapshot?.recentEvents?[2].code, "RCS")
    }

    func testAirlineResultEvidenceRequiresAWBAndResultHints() {
        XCTAssertTrue(TrackingWebResultDetector.hasEvidence(
            text: "910-18733654 Last Activity Arrived at MCT Status History",
            awb: "91018733654",
            source: .airline
        ))
        XCTAssertFalse(TrackingWebResultDetector.hasEvidence(
            text: "Track Air Waybill Prefix AWB No's",
            awb: "91018733654",
            source: .airline
        ))
    }

    func testTransomTextParserDetectsShortLandFromReceivedPieces() {
        let text = """
        AWB 910-18733654
        Shipment Status Arrived
        Manifested Pcs 12
        Received Pcs 10
        Received Weight 240 KG
        Last Event RCF - Received From Flight
        """

        let snapshot = TrackingSourceTextParser.transomSnapshot(
            from: text,
            sourceURL: AirCargoTrackingService.transomTrackingURL
        )

        XCTAssertEqual(snapshot?.expectedPieces, 12)
        XCTAssertEqual(snapshot?.receivedPieces, 10)
        XCTAssertEqual(snapshot?.shortLandedPieces, 2)
        XCTAssertEqual(snapshot?.arrivalState, .partial)
    }

    func testTransomExplicitShortLandWinsWhenPresent() {
        let text = """
        AWB 910-18733654
        Arrival Status PARTIAL
        Received Pieces: 10
        Short Landed: 4
        Gross Weight: 111.50 KG
        Last Event: Cargo received from flight
        """
        let snapshot = TrackingSourceTextParser.transomSnapshot(
            from: text,
            sourceURL: AirCargoTrackingService.transomTrackingURL
        )

        XCTAssertEqual(snapshot?.receivedPieces, 10)
        XCTAssertEqual(snapshot?.shortLandedPieces, 4)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "111.50"))
        XCTAssertEqual(snapshot?.arrivalState, .partial)
    }

    func testTransomResultEvidenceRejectsEntryFormButAcceptsResult() {
        let formOnly = "Shipment Tracking Webtrack+ AWB * HAWB Track and Trace 200 - OK"
        XCTAssertFalse(TrackingWebResultDetector.hasEvidence(text: formOnly, awb: "91018733654", source: .transom))

        let result = "AWB 910-18733654 Shipment Status Arrived Received Pieces 14 Weight 111.50 KG"
        XCTAssertTrue(TrackingWebResultDetector.hasEvidence(text: result, awb: "91018733654", source: .transom))
    }

    func testTransomInjectedAutomationUsesMainFrameBridgeAndFrameworkEvents() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "910", serial: "18733654", fullAWB: "91018733654", source: .transom, mode: .singleAWB
        )

        XCTAssertTrue(script.contains("trackingBridge"))
        XCTAssertTrue(script.contains("MutationObserver"))
        XCTAssertTrue(script.contains("InputEvent"))
        XCTAssertTrue(script.contains("Track and Trace"))
        XCTAssertTrue(script.contains("findTransomTrackAction"))
        XCTAssertTrue(script.contains("track-button-not-found"))
        XCTAssertTrue(script.contains("action.click()"))
        XCTAssertTrue(script.contains("910-18733654"))
        XCTAssertTrue(script.contains("91018733654"))
        XCTAssertTrue(script.contains("hawb"))
        XCTAssertFalse(script.contains("contentDocument"))
        XCTAssertTrue(script.contains("postTransomFormSnapshot"))
    }

    func testKnownAirlineDirectoryCoversMultipleCarriersNotOnlyOmanAir() {
        let expected: [(String, String)] = [
            ("910", "Oman Air Cargo"),
            ("176", "Emirates SkyCargo"),
            ("157", "Qatar Airways Cargo"),
            ("607", "Etihad Cargo"),
            ("235", "Turkish Cargo"),
            ("065", "Saudia Cargo"),
            ("020", "Lufthansa Cargo"),
            ("172", "Cargolux"),
            ("071", "Ethiopian Cargo"),
            ("072", "Gulf Air Cargo"),
            ("160", "Cathay Cargo"),
            ("618", "Singapore Airlines Cargo"),
            ("057", "Air France KLM Martinair Cargo"),
            ("074", "KLM Cargo"),
            ("125", "British Airways Cargo"),
            ("098", "Air India Cargo"),
            ("229", "Kuwait Airways Cargo"),
            ("514", "Air Arabia Cargo"),
            ("960", "SalamAir")
        ]

        for (prefix, name) in expected {
            XCTAssertEqual(AirlineDirectory.source(forPrefix: prefix)?.name, name, "Missing/incorrect carrier for AWB prefix \(prefix)")
            XCTAssertNotNil(AirlineDirectory.source(forPrefix: prefix)?.trackingURL, "Missing official tracking URL for \(prefix)")
        }
    }


    func testSalamAirPrefixIsRecognizedWithPublicFallbackRouter() {
        let source = AirlineDirectory.source(forPrefix: "960")
        XCTAssertEqual(source?.name, "SalamAir")
        XCTAssertEqual(source?.iataCode, "OV")
        XCTAssertEqual(source?.trackingURL?.host, "touch.track-trace.com")
    }

    func testCarrierProfilesUseOmanPreparedURLAndEmiratesOfficialSPA() {
        let oman = TrackingCarrierProfile.profile(prefix: "910", fallbackURL: URL(string: "https://cargo.omanair.com/track-shipment"))
        XCTAssertEqual(oman.mode, .queryPrepared)
        XCTAssertTrue(oman.requestURL(awb: "91018733654")?.absoluteString.contains("FrmAWBTracking.aspx") == true)

        let emirates = TrackingCarrierProfile.profile(prefix: "176", fallbackURL: URL(string: "https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer"))
        XCTAssertEqual(emirates.mode, .emiratesDocNumber)
        XCTAssertEqual(emirates.requestURL(awb: "17612345678")?.host, "eskycargo.emirates.com")

        let turkish = TrackingCarrierProfile.profile(prefix: "235", fallbackURL: URL(string: "https://www.turkishcargo.com/en/cargo-tracking"))
        XCTAssertEqual(turkish.mode, .turkishAWBToken)
        XCTAssertEqual(turkish.requestURL(awb: "23596793771")?.path, "/en/cargo-tracking")

        let qatar = TrackingCarrierProfile.profile(prefix: "157", fallbackURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment"))
        XCTAssertEqual(qatar.mode, .qatarMAWB)
        let qatarURL = qatar.requestURL(awb: "15754645710")
        XCTAssertEqual(qatarURL?.host, "www.qrcargo.com")
        XCTAssertEqual(qatarURL?.path, "/s/track-your-shipment")
        let qatarItems = URLComponents(url: qatarURL!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(qatarItems.first(where: { $0.name == "documentNumber" })?.value, "54645710")
        XCTAssertEqual(qatarItems.first(where: { $0.name == "documentPrefix" })?.value, "157")
        XCTAssertEqual(qatarItems.first(where: { $0.name == "documentType" })?.value, "MAWB")
    }

    func testRemainingCarrierProfilesUseDeterministicOfficialOrPublicFallbackStrategies() {
        let etihad = TrackingCarrierProfile.profile(prefix: "607", fallbackURL: nil)
        XCTAssertEqual(etihad.mode, .trackTraceAuto)
        XCTAssertEqual(etihad.requestURL(awb: "60712345678")?.host, "touch.track-trace.com")

        let saudia = TrackingCarrierProfile.profile(prefix: "065", fallbackURL: nil)
        let saudiaAttempts = saudia.resolvedAttempts(awb: "06512345678")
        XCTAssertEqual(saudiaAttempts.first?.mode, .singleAWB)
        XCTAssertEqual(saudiaAttempts.last?.mode, .trackTraceAuto)
        XCTAssertTrue(saudiaAttempts.contains(where: { $0.url.absoluteString.contains("awbNumber=06512345678") }))

        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "020", fallbackURL: nil).mode, .prefixAndSerial)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "071", fallbackURL: nil).mode, .singleAWB)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "072", fallbackURL: nil).mode, .serialAWB)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "160", fallbackURL: nil).mode, .prefixAndSerial)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "618", fallbackURL: nil).mode, .adaptive)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "057", fallbackURL: nil).mode, .adaptive)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "074", fallbackURL: nil).mode, .singleAWB)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "125", fallbackURL: nil).mode, .adaptive)
        let airIndia = TrackingCarrierProfile.profile(prefix: "098", fallbackURL: nil)
        let airIndiaAttempts = airIndia.resolvedAttempts(awb: "09812345678")
        XCTAssertEqual(airIndiaAttempts.first?.mode, .airIndiaCargo)
        XCTAssertEqual(airIndiaAttempts.first?.url.host, "aicargoportal.airindia.com")
        XCTAssertTrue(airIndiaAttempts.first?.url.absoluteString.contains("#/app") == true)
        XCTAssertFalse(airIndiaAttempts.contains(where: { $0.url.host == "cargo.airindia.com" }))
        XCTAssertEqual(airIndiaAttempts.last?.mode, .trackTraceAuto)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "229", fallbackURL: nil).mode, .prefixAndSerial)
        XCTAssertEqual(TrackingCarrierProfile.profile(prefix: "514", fallbackURL: nil).mode, .airArabia)

        let salam = TrackingCarrierProfile.profile(prefix: "960", fallbackURL: nil).resolvedAttempts(awb: "96012345678")
        XCTAssertEqual(salam.first?.mode, .trackTraceAuto)
        XCTAssertTrue(salam.contains(where: { $0.url.host == "thedeliverytracker.com" }))
    }

    func testGenericAirlineAutomationSupportsShadowDOMFramesAndFallbackSubmissionShapes() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "607", serial: "12345678", fullAWB: "60712345678", source: .airline, mode: .trackTraceAuto
        )

        XCTAssertTrue(script.contains("deepRoots"))
        XCTAssertTrue(script.contains("track direct"))
        XCTAssertTrue(script.contains("full-11-digit-awb"))
        XCTAssertTrue(script.contains("requestSubmit"))
        XCTAssertTrue(script.contains("pressEnter"))
        XCTAssertTrue(script.contains("fastCarrierAttempt ? 28"))
    }

    func testAirIndia098AutomationUsesFullAWBAndExactNextAction() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "098", serial: "12345678", fullAWB: "09812345678", source: .airline, mode: .airIndiaCargo
        )

        XCTAssertTrue(script.contains("shipmentValue"))
        XCTAssertTrue(script.contains("findAirIndiaNextAction"))
        XCTAssertTrue(script.contains("air-india-full-awb-next"))
        XCTAssertTrue(script.contains("cfg.mode === 'airIndiaCargo'"))
    }

    func testAirArabiaAutomationConfiguresCarrierSelector() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "514", serial: "12345678", fullAWB: "51412345678", source: .airline, mode: .airArabia
        )
        XCTAssertTrue(script.contains("configureAirArabiaCarrier"))
        XCTAssertTrue(script.contains("air arabia"))
        XCTAssertTrue(script.contains("514"))
    }

    func testGenericAirlineParserExtractsRouteWeightPiecesFlightAndRecentEvents() {
        let text = """
        AWB 020-12345678
        FRA - MCT
        2 PCS | 125.5 KG
        Shipment History
        Accepted FRA 25 Aug 2026 08:00
        Departed from FRA LH820 25 Aug 2026 12:30
        Arrived at MCT 26 Aug 2026 04:10
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Lufthansa Cargo",
            airlinePrefix: "020",
            sourceURL: URL(string: "https://www.lufthansa-cargo.com/en/eservices/etracking")!
        )

        XCTAssertEqual(snapshot?.origin, "FRA")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 2)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "125.5"))
        XCTAssertEqual(snapshot?.flightNumber, "LH820")
        XCTAssertEqual(snapshot?.status, "Arrived")
        XCTAssertEqual(snapshot?.recentEvents?.count, 3)
        XCTAssertEqual(snapshot?.recentEvents?.first?.title, "Arrived")
    }

    func testQatarAutomationUsesDeepLinkAndShadowDOMFallback() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "157", serial: "54645710", fullAWB: "15754645710", source: .airline, mode: .qatarMAWB
        )

        XCTAssertTrue(script.contains("qatarMAWB"))
        XCTAssertTrue(script.contains("deepRoots"))
        XCTAssertTrue(script.contains("deepQueryAll"))
        XCTAssertTrue(script.contains("submitQatar"))
        XCTAssertTrue(script.contains("track shipment(s)"))
        XCTAssertTrue(script.contains("yes, got it"))
        XCTAssertTrue(script.contains("qatar-dom-complete"))
    }

    func testQatarCargoParserReadsFullOfficialTimeline() {
        let text = """
        157- 54645710 (ORD - MCT)
        1 Piece(s) | 452.7 Kg | 1 m3
        Received at Destination
        Notified consignee
        1 Pcs | 452.7 Kg
        Thu, 27 Aug 2026 00:28
        Received in MCT
        1 Pcs | 452.7 Kg
        Thu, 27 Aug 2026 00:25
        Arrived in MCT on QR 1124/26-Aug-2026
        1 Pcs | 452.7 Kg | 1.17 m3
        Wed, 26 Aug 2026 21:34
        Departed from DOH on QR1124/26-Aug-2026
        1 Pcs | 452.7 Kg | 1.17 m3
        Wed, 26 Aug 2026 19:07
        Received in DOH
        1 Pcs | 452.7 Kg | 1.17 m3
        Tue, 25 Aug 2026 13:29
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Qatar Airways Cargo",
            airlinePrefix: "157",
            sourceURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment")!
        )

        XCTAssertEqual(snapshot?.origin, "ORD")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 1)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "452.7"))
        XCTAssertEqual(snapshot?.flightNumber, "QR1124")
        XCTAssertEqual(snapshot?.status, "Notified consignee")
        XCTAssertEqual(snapshot?.arrival, "Wed, 26 Aug 2026 21:34")
        XCTAssertEqual(snapshot?.recentEvents?.count, 5)
        XCTAssertEqual(snapshot?.recentEvents?[0].title, "Notified consignee")
        XCTAssertEqual(snapshot?.recentEvents?[0].location, "MCT")
        XCTAssertEqual(snapshot?.recentEvents?[0].code, "NFD")
        XCTAssertEqual(snapshot?.recentEvents?[1].title, "Received in MCT")
        XCTAssertEqual(snapshot?.recentEvents?[2].title, "Arrived in MCT on QR 1124/26-Aug-2026")
        XCTAssertEqual(snapshot?.recentEvents?[2].flightNumber, "QR1124")
        XCTAssertEqual(snapshot?.recentEvents?[3].title, "Departed from DOH on QR1124/26-Aug-2026")
        XCTAssertEqual(snapshot?.recentEvents?[4].title, "Received in DOH")
    }

    func testQatarCargoParserAlsoWorksBeforeDestinationNotification() {
        let text = """
        157- 12345678 (ORD - MCT)
        2 Piece(s) | 120.5 Kg | 0.8 m3
        Departed from DOH on QR1124/28-Aug-2026
        2 Pcs | 120.5 Kg | 0.8 m3
        Fri, 28 Aug 2026 19:07
        Received in DOH
        2 Pcs | 120.5 Kg | 0.8 m3
        Fri, 28 Aug 2026 16:30
        """

        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Qatar Airways Cargo",
            airlinePrefix: "157",
            sourceURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment")!
        )

        XCTAssertEqual(snapshot?.status, "Departed from DOH on QR1124/28-Aug-2026")
        XCTAssertEqual(snapshot?.recentEvents?.count, 2)
        XCTAssertEqual(snapshot?.recentEvents?[0].location, "DOH")
        XCTAssertNil(snapshot?.arrival)
    }

    func testEmiratesAutomationWaitsForExpandedPiecesAndGrossWeight() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "176", serial: "27188184", fullAWB: "17627188184", source: .airline, mode: .emiratesDocNumber
        )

        XCTAssertTrue(script.contains("emiratesDOMLooksComplete"))
        XCTAssertTrue(script.contains("Gross Weight"))
        XCTAssertTrue(script.contains("show details"))
        XCTAssertTrue(script.contains("emirates-details-expand"))
        XCTAssertTrue(script.contains("emirates-dom-complete"))
        XCTAssertTrue(script.contains("emirates-rendered-details"))
    }

    func testEmiratesOfficialTrackerParserReadsGuestResultCard() {
        let text = """
        Search Results (1)
        Delivered to the Consignee
        Doc. No.: 176-27188184 Hard Freight
        JRN No.: 65547938
        ATHENS (ATH) ----------> MUSCAT (MCT)
        Pieces 3
        Gross Weight 84 K
        Volume 0.10314 CM
        Chargeable Weight 84 K
        Product Code AXA
        Goods Description SHIP SPARES (E0062)
        """

        let url = URL(string: "https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer")!
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Emirates SkyCargo",
            airlinePrefix: "176",
            sourceURL: url
        )

        XCTAssertEqual(snapshot?.origin, "ATH")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 3)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "84"))
        XCTAssertEqual(snapshot?.status, "Delivered to the Consignee")
        XCTAssertEqual(snapshot?.lastEvent, "Delivered to the Consignee")
    }

    func testTurkishCargoAutomationCommitsSerialTokenBeforeSearch() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "235", serial: "96793771", fullAWB: "23596793771", source: .airline, mode: .turkishAWBToken
        )

        XCTAssertTrue(script.contains("submitTurkish"))
        XCTAssertTrue(script.contains("awb prefix"))
        XCTAssertTrue(script.contains("add: ' + cfg.serial"))
        XCTAssertTrue(script.contains("key: 'Enter'"))
        XCTAssertTrue(script.contains("turkish-submit"))
        XCTAssertTrue(script.contains("turkish-dom-complete"))
        XCTAssertTrue(script.contains("turkish-rendered-details"))
        XCTAssertTrue(script.contains("accept all"))
    }

    func testTurkishCargoParserPrefersLatestOperationalEventCard() {
        let text = """
        Cargo Reservation Information
        Last Acceptance Date and Time: 24.08.2026 19:25
        TK0027 TK6248
        Flight Date 24.08.2026
        ETA 25.08.2026 05:25
        ETD 24.08.2026 22:25
        Segment PVG-IST
        Pieces/Weight 1 / 543 kg
        235-96793771
        1 piece(s)
        543.00 kg
        2.40 m3
        From
        PVG - PUDONG INTL AIRPORT
        To
        MCT - MUSCAT AIRPORT
        In Transit - MCT
        26 Aug 2026 14:42
        Station MCT Flight no TK6248 RCF
        Description Shipment Received From Flight
        Planned pieces/weight 1 / 543 kg
        Actual pieces / weight 1 / 543 kg
        Actual time 26.08.2026 14:38
        ETA 26.08.2026 09:25
        ETD 26.08.2026 03:35
        Station MCT NFD
        Description Shipment Notified For Delivery
        Planned pieces/weight 1 / 543 kg
        Actual pieces / weight 1 / 543 kg
        Actual time 26.08.2026 14:42
        """

        let url = URL(string: "https://www.turkishcargo.com/en/cargo-tracking")!
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Turkish Cargo",
            airlinePrefix: "235",
            sourceURL: url
        )

        XCTAssertEqual(snapshot?.flightNumber, "TK6248")
        XCTAssertEqual(snapshot?.origin, "PVG")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.pieces, 1)
        XCTAssertEqual(snapshot?.weightKg, Decimal(string: "543.00"))
        XCTAssertEqual(snapshot?.status, "Ready for Delivery")
        XCTAssertEqual(snapshot?.lastEvent, "NFD - Shipment Notified For Delivery — 26 Aug 2026 14:42")
        XCTAssertEqual(snapshot?.recentEvents?.count, 2)
        XCTAssertEqual(snapshot?.recentEvents?[0], TrackingEvent(code: "NFD", title: "Shipment Notified For Delivery", location: "MCT", timestamp: "26 Aug 2026 14:42"))
        XCTAssertEqual(snapshot?.recentEvents?[1], TrackingEvent(code: "RCF", title: "Shipment Received From Flight", location: "MCT", timestamp: "26 Aug 2026 14:38", flightNumber: "TK6248"))
    }

    func testTurkishCargoParserUsesDestinationRCFWhenNFDIsAbsent() {
        let text = """
        235-96793771
        1 piece(s)
        543.00 kg
        From PVG - PUDONG INTL AIRPORT
        To MCT - MUSCAT AIRPORT
        In Transit - MCT
        Station MCT Flight no TK6248 RCF
        Description Shipment Received From Flight
        Planned pieces/weight 1 / 543 kg
        Actual pieces / weight 1 / 543 kg
        Actual time 26.08.2026 14:38
        """

        let url = URL(string: "https://www.turkishcargo.com/en/cargo-tracking")!
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Turkish Cargo",
            airlinePrefix: "235",
            sourceURL: url
        )

        XCTAssertEqual(snapshot?.status, "Arrived - MCT")
        XCTAssertEqual(snapshot?.lastEvent, "RCF - Shipment Received From Flight — 26 Aug 2026 14:38")
    }

    func testTurkishCargoParserDoesNotTreatTransitRCFAsFinalArrival() {
        let text = """
        235-96793771
        1 piece(s)
        543.00 kg
        From PVG - PUDONG INTL AIRPORT
        To MCT - MUSCAT AIRPORT
        In Transit - MCT
        25 Aug 2026 05:30
        Station IST Flight no TK0027 RCF
        Description Shipment Received From Flight
        Planned pieces/weight 1 / 543 kg
        Actual pieces / weight 1 / 543 kg
        Actual time 25.08.2026 05:30
        """

        let url = URL(string: "https://www.turkishcargo.com/en/cargo-tracking")!
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Turkish Cargo",
            airlinePrefix: "235",
            sourceURL: url
        )

        XCTAssertEqual(snapshot?.status, "In Transit - MCT")
        XCTAssertEqual(snapshot?.lastEvent, "In Transit - MCT — 25 Aug 2026 05:30")
    }

    func testTurkishCargoEvidenceRejectsEmptyFormAndAcceptsShipmentCard() {
        XCTAssertFalse(TrackingWebResultDetector.hasEvidence(
            text: "Cargo Tracking Information AWB prefix 235 AWB no Search",
            awb: "23596793771",
            source: .airline
        ))
        XCTAssertTrue(TrackingWebResultDetector.hasEvidence(
            text: "235-96793771 1 piece(s) 543.00 kg From PVG - PUDONG INTL AIRPORT To MCT - MUSCAT AIRPORT In Transit - MCT",
            awb: "23596793771",
            source: .airline
        ))
    }

    func testTransomParserAcceptsOperationalCargoWording() {
        let text = """
        Shipment Details
        AWB 176-12345678
        Status RCF - Received From Flight
        Manifested Pieces 14
        Received Pieces 12
        Gross Weight 111.50 KG
        Last Event Cargo Received From Flight
        """

        let snapshot = TrackingSourceTextParser.transomSnapshot(
            from: text,
            sourceURL: AirCargoTrackingService.transomTrackingURL
        )

        XCTAssertEqual(snapshot?.expectedPieces, 14)
        XCTAssertEqual(snapshot?.receivedPieces, 12)
        XCTAssertEqual(snapshot?.shortLandedPieces, 2)
        XCTAssertEqual(snapshot?.arrivalState, .partial)
    }

    func testTrackingServiceNeverFabricatesLiveDataWithoutConnectors() async throws {
        let service = AirCargoTrackingService()
        let result = try await service.track(awb: "176-12345678")

        XCTAssertEqual(result.airline.sourceState, .sourceOnly)
        XCTAssertEqual(result.transom.sourceState, .sourceOnly)
        XCTAssertNil(result.airline.pieces)
        XCTAssertNil(result.transom.receivedPieces)
        XCTAssertEqual(result.transom.arrivalState, .unknown)
    }

    func testTransomProductionResultForKnownOmanAirAWB() {
        let text = """
        Shipment Tracking
        AWB 910-18733654
        HAWB
        Total Pieces 14
        AWB Details
        AWB 910-18733654
        Import/Export Import
        Origin LHR
        Destination MCT
        Received Pieces 14
        Agent (BSA)BADAR SHIPPING AGENCIES LLC
        Freight Information
        Flight No WY0104
        Flight Date 16 AUGUST 2026
        Origin LHR
        Events Status
        Flight Arrival 16 AUGUST 2026 18:50 WY 0104 14PCS
        Shipment ready for delivery 16 AUGUST 2026 20:26 14PCS
        Air Waybill Document delivered 25 AUGUST 2026 14:02
        Document Released
        __CT_TABLE_ROWS__
        AWB | HAWB | Total Pieces
        910-18733654 |  | 14
        AWB | 910-18733654
        HAWB |
        Import/Export | Import
        Origin | LHR
        Destination | MCT
        SHC |
        Received Pieces | 14
        Received Weight |
        Agent | (BSA)BADAR SHIPPING AGENCIES LLC
        Flight No | Flight Date | Origin
        WY0104 | 16 AUGUST 2026 | LHR
        Status | Event Name
        Flight Arrival 16 AUGUST 2026 18:50 WY 0104 14PCS | Flight Arrival
        Shipment ready for delivery 16 AUGUST 2026 20:26 14PCS | Shipment ready for delivery
        Air Waybill Document delivered 25 AUGUST 2026 14:02 | Document Released
        """

        XCTAssertTrue(TrackingWebResultDetector.hasEvidence(text: text, awb: "91018733654", source: .transom))
        let snapshot = TrackingSourceTextParser.transomSnapshot(from: text, sourceURL: AirCargoTrackingService.transomTrackingURL)
        XCTAssertEqual(snapshot?.expectedPieces, 14)
        XCTAssertEqual(snapshot?.receivedPieces, 14)
        XCTAssertNil(snapshot?.shortLandedPieces)
        XCTAssertEqual(snapshot?.arrivalState, .arrived)
        XCTAssertEqual(snapshot?.origin, "LHR")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.flightNumber, "WY0104")
        XCTAssertEqual(snapshot?.flightDate, "16 AUGUST 2026")
        XCTAssertEqual(snapshot?.importExport, "Import")
        XCTAssertEqual(snapshot?.agent, "(BSA)BADAR SHIPPING AGENCIES LLC")
        XCTAssertEqual(snapshot?.status, "Document Released")
        XCTAssertEqual(snapshot?.lastEvent, "Document Released — 25 AUGUST 2026 14:02")
        XCTAssertEqual(snapshot?.recentEvents?.count, 3)
        XCTAssertEqual(snapshot?.recentEvents?[0].code, "DOC")
        XCTAssertEqual(snapshot?.recentEvents?[0].title, "Document Released")
        XCTAssertEqual(snapshot?.recentEvents?[1].code, "RFD")
        XCTAssertEqual(snapshot?.recentEvents?[2].code, "ARR")
    }

    func testTransomAutomationTargetsRealResultMarkersAndWaitsForValidation() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "910", serial: "18733654", fullAWB: "91018733654", source: .transom, mode: .singleAWB
        )
        XCTAssertTrue(script.contains("AWB Details".lowercased()) || script.contains("awb details"))
        XCTAssertTrue(script.contains("received pieces"))
        XCTAssertTrue(script.contains("freight information"))
        XCTAssertTrue(script.contains("events status"))
        XCTAssertTrue(script.contains("transom-split-controls"))
        XCTAssertTrue(script.contains("awbprefix"))
        XCTAssertTrue(script.contains("awbnumber"))
        XCTAssertTrue(script.contains("splitControlsValid"))
        XCTAssertTrue(script.contains("angularFormValid"))
        XCTAssertTrue(script.contains("910 - 18733654"))
        XCTAssertTrue(script.contains("actionDisabled"))
        XCTAssertTrue(script.contains("__CT_TABLE_ROWS__"))
    }

    func testTransomNetworkFallbackTextParsesLikeRenderedDOM() {
        let text = """
        AWB 910 - 18733654
        total Pieces | 14
        received Pieces | 14
        origin | LHR
        destination | MCT
        flight No | WY0104
        flight Date | 16 AUGUST 2026
        event Name | Shipment ready for delivery
        event Name | Document Released
        __CT_TABLE_ROWS__
        total Pieces | 14
        received Pieces | 14
        origin | LHR
        destination | MCT
        flight No | WY0104
        flight Date | 16 AUGUST 2026
        event Name | Document Released
        """

        XCTAssertTrue(TrackingWebResultDetector.hasEvidence(text: text, awb: "91018733654", source: .transom))
        let snapshot = TrackingSourceTextParser.transomSnapshot(from: text, sourceURL: AirCargoTrackingService.transomTrackingURL)
        XCTAssertEqual(snapshot?.expectedPieces, 14)
        XCTAssertEqual(snapshot?.receivedPieces, 14)
        XCTAssertEqual(snapshot?.origin, "LHR")
        XCTAssertEqual(snapshot?.destination, "MCT")
        XCTAssertEqual(snapshot?.flightNumber, "WY0104")
        XCTAssertEqual(snapshot?.flightDate, "16 AUGUST 2026")
        XCTAssertEqual(snapshot?.status, "Document Released")
    }

    func testTransomRenderedEventsProvideLatestEventAndReceivedPieces() {
        let text = """
        Shipment Tracking
        AWB 910-18733654
        Events Status
        __CT_TABLE_ROWS__
        Flight No | Flight Date | Origin
        WY0104 | 16 AUGUST 2026 | LHR
        Status | Event Name
        Flight Arrival 16 AUGUST 2026 18:50 WY 0104 14PCS | Flight Arrival
        Shipment ready for delivery 16 AUGUST 2026 20:26 14PCS | Shipment ready for delivery
        Air Waybill Document delivered 25 AUGUST 2026 14:02 | Document Released
        """

        let snapshot = TrackingSourceTextParser.transomSnapshot(from: text, sourceURL: AirCargoTrackingService.transomTrackingURL)
        XCTAssertEqual(snapshot?.receivedPieces, 14)
        XCTAssertEqual(snapshot?.expectedPieces, 14)
        XCTAssertEqual(snapshot?.flightNumber, "WY0104")
        XCTAssertEqual(snapshot?.flightDate, "16 AUGUST 2026")
        XCTAssertEqual(snapshot?.origin, "LHR")
        XCTAssertEqual(snapshot?.status, "Document Released")
        XCTAssertEqual(snapshot?.lastEvent, "Document Released — 25 AUGUST 2026 14:02")
        XCTAssertEqual(snapshot?.arrivalState, .arrived)
    }

    func testTrackingWorkerKeepsTransomWebViewOnscreenForAngularRendering() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CustomsToolkit/Services/AirCargoWebTrackingResolver.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("CGRect(x: -1200, y: -1200"))
        XCTAssertTrue(source.contains("webView.frame = window.bounds"))
        XCTAssertTrue(source.contains("window.addSubview(webView)"))
    }

    func testTransomAutomationUsesSplitAngularControlsAndNetworkReadFallback() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "910", serial: "18733654", fullAWB: "91018733654", source: .transom, mode: .singleAWB
        )

        XCTAssertTrue(script.contains("transom-split-controls"))
        XCTAssertTrue(script.contains("formcontrolname')) === 'awbprefix'"))
        XCTAssertTrue(script.contains("formcontrolname')) === 'awbnumber'"))
        XCTAssertTrue(script.contains("splitControlsValid && angularFormValid"))
        XCTAssertTrue(script.contains("transom-network-response"))
        XCTAssertTrue(script.contains("transom-dom-complete"))
        XCTAssertTrue(script.contains("rendered-dom"))
        XCTAssertTrue(script.contains("transom-network-fallback-used"))
        XCTAssertFalse(script.contains("transport: 'network-response'"))
        XCTAssertTrue(script.contains("XMLHttpRequest.prototype.send"))
        XCTAssertTrue(script.contains("response.clone()"))
        XCTAssertTrue(script.contains("findTransomTrackAction"))

        if let start = script.range(of: "const submitTransom = async () =>"),
           let end = script.range(of: "const submitGenericAirline", range: start.upperBound..<script.endIndex) {
            let transomSubmit = String(script[start.lowerBound..<end.lowerBound])
            XCTAssertFalse(transomSubmit.contains("findAction()"))
            XCTAssertFalse(transomSubmit.contains("requestSubmit"))
            XCTAssertFalse(transomSubmit.contains("key: 'Enter'"))
            XCTAssertTrue(transomSubmit.contains("action.click()"))
        } else {
            XCTFail("Could not isolate Transom submit block")
        }
    }


    func testProgressiveTrackingShowsOptimizedAirlineBeforeTransom() async throws {
        let airlineSnapshot = AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: "Turkish Cargo",
            airlinePrefix: "235",
            pieces: 1,
            status: "Ready for Delivery"
        )
        let transomSnapshot = TransomTrackingSnapshot(
            sourceState: .live,
            arrivalState: .arrived,
            receivedPieces: 1,
            expectedPieces: 1
        )
        let service = AirCargoTrackingService(
            airlineResolver: StubAirlineResolver(snapshot: airlineSnapshot),
            transomResolver: StubTransomResolver(snapshot: transomSnapshot)
        )

        var updates: [AirCargoTrackingProgress] = []
        for try await update in service.trackProgressively(awb: "235-96793771") {
            updates.append(update)
        }

        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0].completedSource, .airline)
        XCTAssertFalse(updates[0].isFinal)
        XCTAssertEqual(updates[0].result.airline.sourceState, .live)
        XCTAssertEqual(updates[0].result.transom.sourceState, .sourceOnly)
        XCTAssertEqual(updates[1].completedSource, .transom)
        XCTAssertTrue(updates[1].isFinal)
        XCTAssertEqual(updates[1].result.transom.sourceState, .live)
    }

    func testProgressiveTrackingUsesAirlineFirstForQatar() async throws {
        let airlineSnapshot = AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: "Qatar Airways Cargo",
            airlinePrefix: "157",
            status: "In Transit"
        )
        let transomSnapshot = TransomTrackingSnapshot(
            sourceState: .live,
            arrivalState: .arrived,
            receivedPieces: 2,
            expectedPieces: 2,
            status: "Shipment ready for delivery"
        )
        let service = AirCargoTrackingService(
            airlineResolver: StubAirlineResolver(snapshot: airlineSnapshot),
            transomResolver: StubTransomResolver(snapshot: transomSnapshot)
        )

        var updates: [AirCargoTrackingProgress] = []
        for try await update in service.trackProgressively(awb: "157-12345678") {
            updates.append(update)
        }

        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0].completedSource, .airline)
        XCTAssertFalse(updates[0].isFinal)
        XCTAssertEqual(updates[0].result.airline.sourceState, .live)
        XCTAssertEqual(updates[0].result.transom.sourceState, .sourceOnly)
        XCTAssertEqual(updates[1].completedSource, .transom)
        XCTAssertTrue(updates[1].isFinal)
    }

    func testProgressiveTrackingUsesAirlineFirstForAirIndia() async throws {
        let airlineSnapshot = AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: "Air India Cargo",
            airlinePrefix: "098",
            status: "Delivered"
        )
        let transomSnapshot = TransomTrackingSnapshot(
            sourceState: .live,
            arrivalState: .arrived,
            receivedPieces: 11,
            expectedPieces: 11
        )
        let service = AirCargoTrackingService(
            airlineResolver: StubAirlineResolver(snapshot: airlineSnapshot),
            transomResolver: StubTransomResolver(snapshot: transomSnapshot)
        )

        var updates: [AirCargoTrackingProgress] = []
        for try await update in service.trackProgressively(awb: "098-31842230") {
            updates.append(update)
        }

        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0].completedSource, .airline)
        XCTAssertEqual(updates[0].result.airline.sourceState, .live)
        XCTAssertEqual(updates[1].completedSource, .transom)
        XCTAssertTrue(updates[1].isFinal)
    }

    func testAirIndiaTimestampWithCommaAndSecondsSortsNewestFirst() {
        let older = TrackingEvent(code: "ARR", title: "Arrived", location: "MCT", timestamp: "31 Aug 2026, 12:41:00")
        let newer = TrackingEvent(code: "DLV", title: "Delivered", location: "MCT", timestamp: "31 Aug 2026, 12:43:00")
        let sorted = TrackingEventTimestamp.newestFirst([older, newer])
        XCTAssertEqual(sorted.first?.code, "DLV")
    }

    func testTrackingTimestampSupportsWeekdayCommaAfterYear() {
        XCTAssertNotNil(TrackingEventTimestamp.parse("Thu, 27 Aug 2026, 00:28:10"))
    }

    func testBoardStateFallsBackToVerifiedAirlineDestinationEventWhenTransomUnknown() {
        let result = AirCargoTrackingResult(
            awb: "15712345678",
            airline: AirlineTrackingSnapshot(
                sourceState: .live,
                airlineName: "Qatar Airways Cargo",
                airlinePrefix: "157",
                destination: "MCT",
                status: "Received in MCT",
                recentEvents: [TrackingEvent(code: "RCF", title: "Received in MCT", location: "MCT", timestamp: "27 Aug 2026 00:25")]
            ),
            transom: TransomTrackingSnapshot(sourceState: .sourceOnly, arrivalState: .unknown)
        )
        XCTAssertEqual(result.boardState, .arrived)
    }

    func testBoardStateDoesNotTreatOriginArrivalAsDestinationArrival() {
        let result = AirCargoTrackingResult(
            awb: "15712345678",
            airline: AirlineTrackingSnapshot(
                sourceState: .live,
                airlineName: "Qatar Airways Cargo",
                airlinePrefix: "157",
                destination: "MCT",
                status: "Arrived in DOH",
                recentEvents: [TrackingEvent(code: "ARR", title: "Arrived in DOH", location: "DOH", timestamp: "25 Aug 2026 10:35")]
            ),
            transom: TransomTrackingSnapshot(sourceState: .sourceOnly, arrivalState: .unknown)
        )
        XCTAssertNotEqual(result.boardState, .arrived)
    }

    func testTrackTraceAttributionIsNotReportedAsOfficialCarrierSource() {
        let url = URL(string: "https://touch.track-trace.com/aircargo")!
        XCTAssertEqual(TrackingSourceAttribution.kind(for: url), .aggregator)
        XCTAssertEqual(TrackingSourceAttribution.displayName(for: url, carrierName: "Etihad Cargo"), "Track-Trace")
    }

    func testOfficialCarrierAttributionKeepsCarrierName() {
        let url = URL(string: "https://www.qrcargo.com/s/track-your-shipment")!
        XCTAssertEqual(TrackingSourceAttribution.kind(for: url), .officialCarrier)
        XCTAssertEqual(TrackingSourceAttribution.displayName(for: url, carrierName: "Qatar Airways Cargo"), "Qatar Airways Cargo")
    }

    func testQatarCargoParserRecognizesDeliveredAsLatestMilestone() {
        let text = """
        157- 54645710 (ORD - MCT)
        1 Piece(s) | 452.7 Kg | 1 m3
        Delivered
        1 Pcs | 452.7 Kg
        Thu, 27 Aug 2026 08:15
        Notified consignee
        1 Pcs | 452.7 Kg
        Thu, 27 Aug 2026 00:28
        Arrived in MCT on QR 1124/26-Aug-2026
        1 Pcs | 452.7 Kg
        Wed, 26 Aug 2026 21:34
        """
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Qatar Airways Cargo",
            airlinePrefix: "157",
            sourceURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment")!
        )
        XCTAssertEqual(snapshot?.recentEvents?.first?.code, "DLV")
        XCTAssertEqual(snapshot?.status, "Delivered")
    }

    func testSmartKargoEventsUseTimestampOrderRatherThanMilestonePriority() {
        let text = """
        Track Air Waybill
        910-12345678 In Transit
        AWB : 910-12345678 (LHR-MCT) 1 P / 10.0 Kgs
        Booking and Acceptance Information
        Accepted LHR MCT 1 10.0 Kgs 01/09/2026 08:00
        Status History
        MCT Arrived 1 10.0 Kgs WY104 01/09/2026 12:00 LHR MCT
        MCT Departed 1 10.0 Kgs WY200 02/09/2026 09:30 MCT DXB
        """
        let snapshot = TrackingSourceTextParser.airlineSnapshot(
            from: text,
            airlineName: "Oman Air Cargo",
            airlinePrefix: "910",
            sourceURL: URL(string: "https://omanair.smartkargo.com/FrmAWBTracking.aspx")!
        )
        XCTAssertEqual(snapshot?.recentEvents?.first?.code, "DEP")
        XCTAssertEqual(snapshot?.recentEvents?.first?.timestamp, "02/09/2026 09:30")
    }

    func testProgressiveResultMergerKeepsCachedLiveSourceDuringPartialRefresh() {
        let existing = AirCargoTrackingResult(
            awb: "23596793771",
            airline: AirlineTrackingSnapshot(sourceState: .live, airlineName: "Turkish Cargo", status: "Ready for Delivery"),
            transom: TransomTrackingSnapshot(sourceState: .live, arrivalState: .arrived, receivedPieces: 1),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let incoming = AirCargoTrackingResult(
            awb: "23596793771",
            airline: AirlineTrackingSnapshot(sourceState: .live, airlineName: "Turkish Cargo", status: "Delivered"),
            transom: TransomTrackingSnapshot(sourceState: .sourceOnly, arrivalState: .unknown),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let merged = AirCargoTrackingResultMerger.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(merged.airline.status, "Delivered")
        XCTAssertEqual(merged.transom.sourceState, .live)
        XCTAssertEqual(merged.transom.receivedPieces, 1)
        XCTAssertEqual(merged.updatedAt, Date(timeIntervalSince1970: 200))
    }

    func testUnverifiedCarrierAttemptsHaveShorterCeiling() {
        let script = TrackingWebAutomation.injectedScript(
            prefix: "172", serial: "12345678", fullAWB: "17212345678", source: .airline, mode: .adaptive
        )
        XCTAssertTrue(script.contains("fastCarrierAttempt ? 28"))
        XCTAssertTrue(script.contains("!(cfg.mode === 'queryPrepared' && cfg.prefix === '910')"))
    }

}


private struct StubAirlineResolver: AirlineLiveTrackingResolving {
    let snapshot: AirlineTrackingSnapshot

    func fetch(awb: String, source: AirlineTrackingSource?) async throws -> AirlineTrackingSnapshot {
        snapshot
    }
}

private struct StubTransomResolver: TransomLiveTrackingResolving {
    let snapshot: TransomTrackingSnapshot

    func fetch(awb: String) async throws -> TransomTrackingSnapshot {
        snapshot
    }
}
