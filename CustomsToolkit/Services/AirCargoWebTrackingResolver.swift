import Foundation
import WebKit
import UIKit

public enum OfficialWebTrackingError: Error, Sendable {
    case unsupportedSource
    case pageLoadFailed
    case timedOut
    case formNotFound
    case noLiveDataFound
}

/// Live tracking bridge that deliberately avoids repeated `evaluateJavaScript` calls.
///
/// V3.9's polling approach could trigger WebKit's
/// `runJavaScriptInFrameInScriptWorld` failures on real devices. V4 injects one WKUserScript
/// at document end (main-frame-only for Transom; locally in each airline frame where needed),
/// then receives DOM/result updates through a WKScriptMessageHandler. No cross-origin iframe
/// DOM traversal or repeated evaluateJavaScript polling is attempted.
public final class OfficialWebTrackingResolver: AirlineLiveTrackingResolving, TransomLiveTrackingResolving, @unchecked Sendable {
    public static let shared = OfficialWebTrackingResolver()

    public init() {}

    public func fetch(awb: String, source: AirlineTrackingSource?) async throws -> AirlineTrackingSnapshot {
        guard let source else { throw OfficialWebTrackingError.unsupportedSource }
        let normalized = AWBNormalizer.normalized(awb)
        guard let prefix = AWBNormalizer.prefix(normalized), normalized.count == 11 else {
            throw AirCargoTrackingError.invalidAWB
        }

        let serial = String(normalized.dropFirst(3))
        let profile = TrackingCarrierProfile.profile(prefix: prefix, fallbackURL: source.trackingURL)
        let attempts = profile.resolvedAttempts(awb: normalized)
        guard !attempts.isEmpty else { throw OfficialWebTrackingError.unsupportedSource }

        var lastError: Error = OfficialWebTrackingError.noLiveDataFound
        for attempt in attempts {
            do {
                let pageText = try await OfficialTrackingPageReader.read(
                    url: attempt.url,
                    prefix: prefix,
                    serial: serial,
                    fullAWB: normalized,
                    source: .airline,
                    mode: attempt.mode
                )

                guard var snapshot = TrackingSourceTextParser.airlineSnapshot(
                    from: pageText,
                    airlineName: source.name,
                    airlinePrefix: prefix,
                    sourceURL: attempt.url
                ) else {
                    lastError = OfficialWebTrackingError.noLiveDataFound
                    continue
                }

                snapshot.sourceState = .live
                snapshot.dataSourceName = TrackingSourceAttribution.displayName(for: attempt.url, carrierName: source.name)
                snapshot.dataSourceKind = TrackingSourceAttribution.kind(for: attempt.url)
                snapshot.fetchedAt = Date()
                return snapshot
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    public func fetch(awb: String) async throws -> TransomTrackingSnapshot {
        let normalized = AWBNormalizer.normalized(awb)
        guard let prefix = AWBNormalizer.prefix(normalized), normalized.count == 11 else {
            throw AirCargoTrackingError.invalidAWB
        }

        let serial = String(normalized.dropFirst(3))
        let pageText = try await OfficialTrackingPageReader.read(
            url: AirCargoTrackingService.transomTrackingURL,
            prefix: prefix,
            serial: serial,
            fullAWB: normalized,
            source: .transom,
            mode: .singleAWB
        )

        guard var snapshot = TrackingSourceTextParser.transomSnapshot(
            from: pageText,
            sourceURL: AirCargoTrackingService.transomTrackingURL
        ) else {
            throw OfficialWebTrackingError.noLiveDataFound
        }

        snapshot.sourceState = .live
        snapshot.fetchedAt = Date()
        return snapshot
    }
}

enum TrackingWebSource: String, Sendable {
    case airline
    case transom
}

enum TrackingAutomationMode: String, Sendable {
    /// Page can be opened with the AWB already in the URL. The script primarily waits for result text.
    case queryPrepared
    /// One AWB field. The generic submitter chooses formatted/full/serial based on the control shape.
    case singleAWB
    /// Separate carrier-prefix and serial-number controls.
    case prefixAndSerial
    /// One carrier-fixed 8-digit AWB serial field (for example Gulf Air Falcon Cargo).
    case serialAWB
    /// Track-Trace's public air-cargo router: full 11 digits + Track Direct, then capture the result frame/page.
    case trackTraceAuto
    /// Air Arabia public cargo page: carrier selector + tracking ID.
    case airArabia
    /// Air India iCargo guest portal: one full 11-digit AWB field followed by the exact Next action.
    case airIndiaCargo
    /// Emirates SkyCargo eSkyCargo guest screen: one Doc. No. token field + Search button.
    case emiratesDocNumber
    /// Turkish Cargo guest tracker: fixed 235 prefix + AWB serial token + Search.
    case turkishAWBToken
    /// Qatar Airways Cargo: official MAWB deep-link first, with a Shadow-DOM form fallback.
    case qatarMAWB
    /// Best-effort detector: discovers forms across normal DOM, open Shadow DOM and injected frames.
    case adaptive
}

/// Carrier-specific behavior is intentionally separated from the parser so adding another airline
/// does not require changing the tracking screen or the Transom connector.
enum TrackingCarrierProfile {
    struct Attempt: Sendable {
        var mode: TrackingAutomationMode
        var url: URL
    }

    struct AttemptTemplate: Sendable {
        var mode: TrackingAutomationMode
        var baseURL: URL?
        var preparedURL: (@Sendable (String) -> URL?)?

        func resolve(awb: String) -> Attempt? {
            guard let url = preparedURL?(awb) ?? baseURL else { return nil }
            return Attempt(mode: mode, url: url)
        }
    }

    struct Profile: Sendable {
        var prefix: String
        var templates: [AttemptTemplate]

        /// Kept for existing tests/documentation: returns the first configured strategy.
        var mode: TrackingAutomationMode { templates.first?.mode ?? .adaptive }

        func requestURL(awb: String) -> URL? {
            resolvedAttempts(awb: awb).first?.url
        }

        func resolvedAttempts(awb: String) -> [Attempt] {
            var seen = Set<String>()
            return templates.compactMap { $0.resolve(awb: awb) }.filter { attempt in
                let key = attempt.mode.rawValue + "|" + attempt.url.absoluteString
                return seen.insert(key).inserted
            }
        }
    }

    private static let trackTraceURL = URL(string: "https://touch.track-trace.com/aircargo")

    private static func template(
        _ mode: TrackingAutomationMode,
        _ url: String
    ) -> AttemptTemplate {
        AttemptTemplate(mode: mode, baseURL: URL(string: url), preparedURL: nil)
    }

    private static func trackTraceFallback() -> AttemptTemplate {
        AttemptTemplate(mode: .trackTraceAuto, baseURL: trackTraceURL, preparedURL: nil)
    }

    static func profile(prefix: String, fallbackURL: URL?) -> Profile {
        switch prefix {
        case "910":
            return Profile(prefix: prefix, templates: [
                AttemptTemplate(
                    mode: .queryPrepared,
                    baseURL: fallbackURL,
                    preparedURL: { awb in AirlineDirectory.liveTrackingURL(forAWB: awb) }
                )
            ])
        case "176":
            return Profile(prefix: prefix, templates: [
                template(.emiratesDocNumber, "https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer")
            ])
        case "235":
            return Profile(prefix: prefix, templates: [
                template(.turkishAWBToken, "https://www.turkishcargo.com/en/cargo-tracking")
            ])
        case "157":
            return Profile(prefix: prefix, templates: [
                AttemptTemplate(
                    mode: .qatarMAWB,
                    baseURL: URL(string: "https://www.qrcargo.com/s/track-your-shipment"),
                    preparedURL: { awb in
                        let normalized = AWBNormalizer.normalized(awb)
                        guard normalized.count == 11, normalized.hasPrefix("157") else { return nil }
                        let serial = String(normalized.dropFirst(3))
                        var components = URLComponents(string: "https://www.qrcargo.com/s/track-your-shipment")
                        components?.queryItems = [
                            URLQueryItem(name: "documentNumber", value: serial),
                            URLQueryItem(name: "documentPrefix", value: "157"),
                            URLQueryItem(name: "documentType", value: "MAWB")
                        ]
                        return components?.url
                    }
                )
            ])

        // Etihad's current cargo tools are account-oriented. The public Track-Trace router supports
        // EY/607 and is used as the no-login airline-side source, with Transom still displayed separately.
        case "607":
            return Profile(prefix: prefix, templates: [trackTraceFallback()])

        // Saudia's current public Digital Services page embeds Track Shipment in a client-side frame.
        // Try that current official page first; retain the older awbNumber deep link as a compatibility
        // fallback before the public Track-Trace router.
        case "065":
            return Profile(prefix: prefix, templates: [
                template(.singleAWB, "https://www.saudiacargo.com/en/digital-services?tab=trackShipment"),
                AttemptTemplate(
                    mode: .queryPrepared,
                    baseURL: URL(string: "https://saudiacargo.com/e-services/track-shipment"),
                    preparedURL: { awb in
                        var components = URLComponents(string: "https://saudiacargo.com/e-services/track-shipment")
                        components?.queryItems = [URLQueryItem(name: "awbNumber", value: AWBNormalizer.normalized(awb))]
                        return components?.url
                    }
                ),
                trackTraceFallback()
            ])

        case "020":
            return Profile(prefix: prefix, templates: [
                template(.prefixAndSerial, "https://www.lufthansa-cargo.com/en/eservices/etracking"),
                trackTraceFallback()
            ])
        case "172":
            return Profile(prefix: prefix, templates: [
                template(.adaptive, "https://www.cargolux.com/track-and-Trace"),
                trackTraceFallback()
            ])
        case "071":
            return Profile(prefix: prefix, templates: [
                template(.singleAWB, "https://ethiopiancargo.azurewebsites.net/my-cargo/track-your-shipment"),
                trackTraceFallback()
            ])
        case "072":
            return Profile(prefix: prefix, templates: [
                template(.serialAWB, "https://www.gulfair.com/cargo"),
                trackTraceFallback()
            ])
        case "160":
            return Profile(prefix: prefix, templates: [
                template(.prefixAndSerial, "https://www.cathaycargo.com/usrapps/eservices/track/track.aspx"),
                trackTraceFallback()
            ])
        case "618":
            return Profile(prefix: prefix, templates: [
                template(.adaptive, "https://www.siacargo.com"),
                template(.singleAWB, "https://www.siacargo.com/track-shipment/"),
                trackTraceFallback()
            ])

        // AF-KL-MP exposes public Track your shipment entry points, but some myCargo variants can
        // become session-dependent. Try the official page first and keep Track-Trace as the fast fallback.
        case "057":
            return Profile(prefix: prefix, templates: [
                template(.adaptive, "https://www.afklcargo.com/WW/en/homepage/homepage"),
                trackTraceFallback()
            ])
        case "074":
            return Profile(prefix: prefix, templates: [
                template(.singleAWB, "https://www.afklcargo.com/mycargo/shipment/singlesearch"),
                trackTraceFallback()
            ])

        // IAG Cargo documents a public Track and Trace entry point on its homepage for 125 AWBs.
        // Try the official site first and retain the stable public air-cargo router as fallback.
        case "125":
            return Profile(prefix: prefix, templates: [
                template(.adaptive, "https://www.iagcargo.com/en/"),
                trackTraceFallback()
            ])

        case "098":
            return Profile(prefix: prefix, templates: [
                // Air India guest tracking is hosted directly in the iCargo Neo portal. The SPA needs
                // the hash route, then a full 11-digit AWB in #shipmentValue and the exact Next button.
                template(.airIndiaCargo, "https://aicargoportal.airindia.com/icargoneoportal/app/main/#/app"),
                trackTraceFallback()
            ])
        case "229":
            return Profile(prefix: prefix, templates: [
                template(.prefixAndSerial, "https://www.kuwaitairways.com/en/cargo/tracking"),
                trackTraceFallback()
            ])
        case "514":
            return Profile(prefix: prefix, templates: [
                template(.airArabia, "https://cargo.airarabia.com/cargo-tracking/"),
                trackTraceFallback()
            ])
        case "960":
            return Profile(prefix: prefix, templates: [
                trackTraceFallback(),
                template(.singleAWB, "https://thedeliverytracker.com/salam-air-cargo-tracking/")
            ])
        default:
            return Profile(prefix: prefix, templates: [
                AttemptTemplate(mode: .adaptive, baseURL: fallbackURL, preparedURL: nil)
            ])
        }
    }
}

/// Pure helper kept testable independently from WKWebView.
enum TrackingWebResultDetector {
    static func hasEvidence(text: String, awb: String, source: TrackingWebSource) -> Bool {
        let lower = text.lowercased()
        let normalizedBody = AWBNormalizer.normalized(text)
        let normalizedAWB = AWBNormalizer.normalized(awb)

        let noDataTokens = [
            "no data found", "no record found", "no records found", "shipment not found",
            "awb not found", "invalid awb", "no shipment found", "no details found",
            "no shipment information", "awb does not exist", "air waybill not found"
        ]
        if noDataTokens.contains(where: lower.contains) { return true }

        let containsAWB = normalizedBody.contains(normalizedAWB)
        switch source {
        case .airline:
            if normalizedAWB.hasPrefix("176") {
                // eSkyCargo's Find Offers form contains generic Pieces/Weight controls before any
                // search. Require the actual Search Results card to avoid accepting the input chip
                // itself as live tracking evidence.
                return containsAWB && lower.contains("search results") &&
                    (lower.contains("gross weight") || lower.contains("delivered to the consignee"))
            }
            if normalizedAWB.hasPrefix("235") {
                return containsAWB && lower.contains("piece(s)") && lower.contains("kg") &&
                    lower.contains("from") && lower.contains("to")
            }
            if normalizedAWB.hasPrefix("157") {
                let qatarMilestones = [
                    "delivered", "notified consignee", "received at destination", "received in",
                    "arrived in", "departed from"
                ]
                return containsAWB && lower.contains("kg") &&
                    (lower.contains("piece(s)") || lower.contains("pcs")) &&
                    qatarMilestones.contains(where: lower.contains)
            }
            let hints = [
                "booking and acceptance information", "status history", "last activity",
                "shipment details", "shipment history", "tracking result",
                "arrived at", "arrived", "departed", "accepted", "received",
                "ready for delivery", "delivered", "flight", "route",
                "pieces", "pcs", "gross weight", "weight", "origin", "destination"
            ]
            let hintCount = hints.filter { lower.contains($0) }.count
            if normalizedAWB.hasPrefix("910") {
                return containsAWB && hintCount >= 1
            }
            return containsAWB && hintCount >= 2

        case .transom:
            let hints = [
                "received", "arrival", "arrived", "pieces", "pcs", "weight", "flight",
                "shipment details", "status", "rcf", "short land", "shortland",
                "manifested", "breakdown", "ready for delivery"
            ]
            return containsAWB && hints.contains(where: lower.contains)
        }
    }
}

/// Generates one persistent automation script. The script waits for framework hydration, fills the
/// form, submits it, watches DOM mutations, and posts result text back to Swift. For airline pages
/// WebKit injects this script locally into each frame, so no script ever traverses cross-origin iframe DOM.
enum TrackingWebAutomation {
    static func injectedScript(
        prefix: String,
        serial: String,
        fullAWB: String,
        source: TrackingWebSource,
        mode: TrackingAutomationMode
    ) -> String {
        let prefixJS = javaScriptString(prefix)
        let serialJS = javaScriptString(serial)
        let fullJS = javaScriptString(fullAWB)
        let formattedJS = javaScriptString("\(prefix)-\(serial)")
        let spacedFormattedJS = javaScriptString("\(prefix) - \(serial)")
        let sourceJS = javaScriptString(source.rawValue)
        let modeJS = javaScriptString(mode.rawValue)

        return #"""
        (() => {
          if (window.__customsToolkitTrackingBridgeInstalled) return;
          window.__customsToolkitTrackingBridgeInstalled = true;

          const cfg = {
            prefix: \#(prefixJS), serial: \#(serialJS), full: \#(fullJS),
            formatted: \#(formattedJS), spacedFormatted: \#(spacedFormattedJS),
            source: \#(sourceJS), mode: \#(modeJS)
          };

          const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.trackingBridge;
          const post = (kind, payload = {}) => {
            try { bridge && bridge.postMessage(Object.assign({ kind }, payload)); } catch (_) {}
          };
          const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
          const norm = value => (value || '').toString().trim().toLowerCase();
          const digits = value => (value || '').toString().replace(/[^0-9]/g, '');

          // Modern cargo sites increasingly render guest trackers in web components. Walk every
          // *open* ShadowRoot for airline pages. This generalizes the Qatar fix to carriers such as
          // Air India/Cargolux without using repeated evaluateJavaScript-in-frame calls.
          const qatarRootCache = { roots: null, at: 0 };
          const deepRoots = () => {
            const roots = [document];
            if (cfg.source !== 'airline') return roots;
            const now = Date.now();
            if (qatarRootCache.roots && (now - qatarRootCache.at) < 900) return qatarRootCache.roots;
            const queue = [document];
            const seen = new Set();
            let scannedElements = 0;
            while (queue.length && roots.length < 220 && scannedElements < 7000) {
              const root = queue.shift();
              let elements = [];
              try { elements = Array.from(root.querySelectorAll ? root.querySelectorAll('*') : []); } catch (_) {}
              scannedElements += elements.length;
              for (const el of elements) {
                try {
                  if (el.shadowRoot && !seen.has(el.shadowRoot)) {
                    seen.add(el.shadowRoot);
                    roots.push(el.shadowRoot);
                    queue.push(el.shadowRoot);
                  }
                } catch (_) {}
              }
            }
            qatarRootCache.roots = roots;
            qatarRootCache.at = now;
            return roots;
          };
          const deepQueryAll = selector => {
            const output = [];
            for (const root of deepRoots()) {
              try { output.push(...Array.from(root.querySelectorAll(selector))); } catch (_) {}
            }
            return Array.from(new Set(output));
          };
          const qatarShadowText = () => {
            if (cfg.source !== 'airline') return '';
            const chunks = [];
            for (const root of deepRoots().slice(1)) {
              try {
                const text = (root.textContent || '').toString().trim();
                if (text) chunks.push(text);
              } catch (_) {}
            }
            return chunks.join('\n').slice(0, 50000);
          };
          const pageText = () => {
            try {
              const body = (document.body && document.body.innerText) ? document.body.innerText : '';
              const shadow = qatarShadowText();
              return shadow ? body + '\n__CT_SHADOW_TEXT__\n' + shadow : body;
            } catch (_) { return ''; }
          };
          // Keep the human-visible page text, but also append normalized table rows.
          // Transom renders operational data in tables/expansion panels; row boundaries make
          // labels such as Received Pieces, Flight No and Event Name deterministic to parse.
          const resultText = () => {
            const body = pageText();
            if (cfg.source !== 'transom') return body + '\n__CT_REQUESTED_AWB__ ' + cfg.full;
            try {
              const rows = Array.from(document.querySelectorAll('tr')).map(row =>
                Array.from(row.querySelectorAll('th,td'))
                  .map(cell => (cell.innerText || cell.textContent || '').trim().replace(/\s+/g, ' '))
                  .join(' | ')
              ).filter(Boolean);
              return body + '\n__CT_TABLE_ROWS__\n' + rows.join('\n');
            } catch (_) { return body; }
          };
          const hasNoData = text => {
            const l = norm(text);
            return ['no data found','no record found','no records found','shipment not found','awb not found','invalid awb','no shipment found','no details found','no shipment information','awb does not exist','air waybill not found','no shipment details found']
              .some(token => l.includes(token));
          };
          const awbVisible = text => {
            const d = digits(text);
            return text.includes(cfg.formatted) || text.includes(cfg.spacedFormatted) || text.includes(cfg.full) || d.includes(cfg.full);
          };
          const hasTransomResult = text => {
            const l = norm(text);
            if (hasNoData(text)) return true;
            if (!awbVisible(text)) return false;
            // Transom is an SPA: success is the result DOM appearing, not a URL change.
            // Any one of these production markers means the result panel has begun rendering.
            const resultMarkers = ['awb details','received pieces','freight information','events status'];
            return resultMarkers.some(token => l.includes(token));
          };
          const hasAirlineResult = text => {
            const l = norm(text);
            const hrefDigits = digits(location.href);
            const requestReferenceVisible = awbVisible(text) || hrefDigits.includes(cfg.full) ||
              hrefDigits.includes(cfg.serial) || norm(location.href).includes(norm(cfg.serial));
            // In all-frame mode an unrelated shell/marketing frame can contain generic no-data text.
            // Only accept a no-data result after this frame actually submitted the AWB or the request
            // reference is present in its rendered text/URL.
            if (hasNoData(text)) return submitted || requestReferenceVisible;
            if (!requestReferenceVisible) return false;
            if (cfg.mode === 'emiratesDocNumber') {
              // Search Results + the requested AWB means eSkyCargo returned a shipment card.
              // Do NOT finish here: inspect() waits for the detail panel (Gross Weight/Pieces)
              // so the native Emirates card is never returned half-populated.
              return l.includes('search results');
            }
            if (cfg.mode === 'turkishAWBToken') {
              return l.includes('piece(s)') && l.includes('kg') && l.includes('from') && l.includes('to');
            }
            if (cfg.mode === 'qatarMAWB') {
              const milestones = ['delivered','notified consignee','received at destination','received in','arrived in','departed from'];
              return l.includes('kg') && (l.includes('piece(s)') || l.includes('pcs')) && milestones.some(token => l.includes(token));
            }
            if (cfg.mode === 'airIndiaCargo') {
              const milestones = ['delivered','consignee notified','broken down','arrived','departed','manifested','accepted'];
              return l.includes('awb activity timeline') && l.includes('kg') && milestones.some(token => l.includes(token));
            }

            const resultMarkers = [
              'status history', 'booking and acceptance information', 'last activity', 'shipment details',
              'shipment history', 'tracking result', 'arrived at', 'arrived', 'departed', 'accepted',
              'received', 'ready for delivery', 'delivered', 'pieces', 'pcs', 'gross weight', 'weight',
              'origin', 'destination', 'flight'
            ];
            const markerCount = resultMarkers.filter(token => l.includes(token)).length;
            // Preserve the already-verified Oman SmartKargo behavior. For the new generic/portal
            // adapters require two independent result signals so a tracking form is not mistaken
            // for an actual shipment result.
            if (cfg.prefix === '910' && cfg.mode === 'queryPrepared') return markerCount >= 1;
            return markerCount >= 2;
          };
          const hasResultEvidence = text => cfg.source === 'transom' ? hasTransomResult(text) : hasAirlineResult(text);

          // Transom is a JavaScript SPA. If its Track and Trace request uses XHR/fetch, capture that
          // response as a second *read path* in case the hidden WKWebView does not paint the result panel
          // reliably. Submission still happens only through the real Track and Trace button; this code
          // does not call or guess a private endpoint directly.
          let transomNetworkRequests = 0;
          let transomNetworkResponses = 0;
          let transomNetworkFallbackText = '';
          let transomNetworkFallbackAt = 0;
          let transomEvidenceSince = 0;
          let transomLastResultText = '';
          let transomStableReads = 0;
          const humanizeKey = key => (key || '').toString()
            .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
            .replace(/[_\-.]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
          const flattenJSONRows = (value, rows = [], depth = 0) => {
            if (depth > 8 || rows.length > 500) return rows;
            if (Array.isArray(value)) {
              value.forEach(item => flattenJSONRows(item, rows, depth + 1));
              return rows;
            }
            if (value && typeof value === 'object') {
              Object.entries(value).forEach(([key, child]) => {
                if (child === null || child === undefined) return;
                if (typeof child === 'object') {
                  flattenJSONRows(child, rows, depth + 1);
                } else {
                  const label = humanizeKey(key);
                  const rendered = String(child).trim();
                  if (label && rendered) rows.push(label + ' | ' + rendered);
                }
              });
            }
            return rows;
          };
          const transomTrackingPayload = body => {
            if (!body) return null;
            try {
              const parsed = JSON.parse(body);
              const data = parsed && parsed.data;
              if (!parsed || parsed.success !== true || !data || typeof data !== 'object') return null;
              const shipments = Array.isArray(data.trackShipmentList) ? data.trackShipmentList : [];
              const freight = Array.isArray(data.freightInformationList) ? data.freightInformationList : [];
              const events = Array.isArray(data.flightEventsList) ? data.flightEventsList : [];
              if (!shipments.length && !freight.length && !events.length) return null;
              return { parsed, data, shipments, freight, events };
            } catch (_) { return null; }
          };
          const transomNetworkText = body => {
            if (!body) return '';
            const payload = transomTrackingPayload(body);
            if (payload) {
              const shipment = payload.shipments[0] || {};
              const flight = payload.freight[0] || {};
              const rows = [];
              const lines = ['AWB ' + cfg.spacedFormatted, 'AWB Details'];
              const addKV = (label, value) => {
                if (value === null || value === undefined) return;
                const rendered = String(value).trim();
                if (!rendered) return;
                lines.push(label + ' | ' + rendered);
                rows.push(label + ' | ' + rendered);
              };

              addKV('Total Pieces', shipment.totalPcs);
              addKV('Received Pieces', shipment.receivedPcs);
              addKV('Weight', shipment.receivedWeight ?? shipment.totalWeight);
              addKV('Import/Export', shipment.flgImpExp);
              addKV('Irregularity', shipment.irregularity);
              addKV('Agent', shipment.agent);

              if (payload.freight.length) {
                lines.push('Freight Information');
                // Put simple origin/destination key-value rows before the table header so the Swift
                // parser cannot mistake the header's next column (Destination/STA) for the value.
                addKV('Origin', flight.origin);
                addKV('Destination', flight.destination);
                rows.push('Flight No | Flight Date | Origin | Destination | STA | ATA | Pieces | Weight');
                for (const item of payload.freight) {
                  const carrier = String(item.carrier || '').trim();
                  const rawFlight = String(item.flightNo || item.flightKey || '').trim();
                  const flightNo = (carrier && rawFlight.toUpperCase().startsWith(carrier.toUpperCase()) ? rawFlight : carrier + rawFlight).replace(/\s+/g, '');
                  const flightRow = [
                    flightNo,
                    item.flightDate ?? '',
                    item.origin ?? '',
                    item.destination ?? '',
                    item.sta ?? '',
                    item.ata ?? '',
                    item.pcs ?? '',
                    item.weight ?? ''
                  ].map(value => String(value ?? '').trim()).join(' | ');
                  lines.push(flightRow);
                  rows.push(flightRow);
                }
              }

              if (payload.events.length) {
                lines.push('Events Status');
                rows.push('Status | Event Name');
                for (const event of payload.events) {
                  const statusText = String(event.status || '').trim();
                  const eventName = String(event.eventName || '').trim();
                  if (!statusText && !eventName) continue;
                  const eventRow = statusText + ' | ' + eventName;
                  lines.push(eventRow);
                  rows.push(eventRow);
                }
              }

              return lines.join('\n') + '\n__CT_TABLE_ROWS__\n' + rows.join('\n');
            }
            try {
              const parsed = JSON.parse(body);
              const rows = flattenJSONRows(parsed);
              if (!rows.length) return body;
              return 'AWB ' + cfg.spacedFormatted + '\n' + rows.join('\n') +
                '\n__CT_TABLE_ROWS__\n' + rows.join('\n');
            } catch (_) {
              return 'AWB ' + cfg.spacedFormatted + '\n' + body;
            }
          };
          const inspectTransomNetworkResponse = (url, status, body) => {
            if (cfg.source !== 'transom' || (!submitted && !submitting)) return;
            transomNetworkResponses += 1;
            const urlText = (url || '').toString();
            const payload = transomTrackingPayload(body || '');
            const isTrackingEndpoint = urlText.includes('/webtrack-apis/track-shipment');
            const text = transomNetworkText(body || '');
            const relevant = !!payload || hasTransomResult(text) || hasNoData(text);
            post('diagnostic', {
              stage: 'transom-network-response', status: status || 0, relevant,
              networkRequests: transomNetworkRequests, networkResponses: transomNetworkResponses,
              url: urlText.slice(0, 500),
              bodySample: (body || '').toString().replace(/\s+/g, ' ').slice(0, 700)
            });
            if (relevant) {
              transomNetworkFallbackText = text;
              transomNetworkFallbackAt = Date.now();
            }
            // This is Transom's own response produced by the real Track and Trace button. It already
            // contains the complete shipment, freight and event arrays, so prefer it over a partially
            // painted Angular DOM. This avoids losing Received Pieces / Events Status when WebKit idles.
            if (payload && isTrackingEndpoint) {
              post('diagnostic', {
                stage: 'transom-network-authoritative',
                shipmentCount: payload.shipments.length,
                freightCount: payload.freight.length,
                eventCount: payload.events.length,
                href: location.href
              });
              post('result', { text, href: location.href, transport: 'transom-api-response' });
            }
          };
          const installTransomNetworkProbe = () => {
            if (cfg.source !== 'transom' || window.__customsToolkitTransomNetworkProbe) return;
            window.__customsToolkitTransomNetworkProbe = true;
            try {
              const originalFetch = window.fetch;
              if (typeof originalFetch === 'function') {
                window.fetch = function(...args) {
                  const shouldTrack = submitting || submitted;
                  if (shouldTrack) transomNetworkRequests += 1;
                  return originalFetch.apply(this, args).then(response => {
                    if (shouldTrack) {
                      try {
                        const clone = response.clone();
                        clone.text().then(body => inspectTransomNetworkResponse(
                          response.url || (args[0] && args[0].url) || args[0] || '', response.status, body
                        )).catch(() => {});
                      } catch (_) {}
                    }
                    return response;
                  });
                };
              }
            } catch (_) {}

            try {
              const originalOpen = XMLHttpRequest.prototype.open;
              const originalSend = XMLHttpRequest.prototype.send;
              XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                this.__ctTrackingURL = url || '';
                return originalOpen.call(this, method, url, ...rest);
              };
              XMLHttpRequest.prototype.send = function(...args) {
                const shouldTrack = submitting || submitted;
                if (shouldTrack) {
                  transomNetworkRequests += 1;
                  this.addEventListener('loadend', () => {
                    try {
                      const body = typeof this.responseText === 'string' ? this.responseText : '';
                      inspectTransomNetworkResponse(this.responseURL || this.__ctTrackingURL || '', this.status, body);
                    } catch (_) {}
                  }, { once: true });
                }
                return originalSend.apply(this, args);
              };
            } catch (_) {}
          };

          const visible = el => {
            try {
              const style = window.getComputedStyle(el);
              const rect = el.getBoundingClientRect();
              return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
            } catch (_) { return true; }
          };
          const meta = el => norm([
            el.id, el.name, el.placeholder, el.getAttribute('aria-label'),
            el.getAttribute('formcontrolname'), el.getAttribute('data-testid'), el.autocomplete
          ].filter(Boolean).join(' '));
          const contextMeta = el => {
            const chunks = [];
            try {
              if (el.id) {
                const escapedID = (window.CSS && CSS.escape) ? CSS.escape(el.id) : el.id.replace(/[^a-zA-Z0-9_-]/g, '');
                const label = escapedID ? document.querySelector('label[for="' + escapedID + '"]') : null;
                if (label) chunks.push(label.innerText || label.textContent || '');
              }
            } catch (_) {}
            try {
              const wrappingLabel = el.closest && el.closest('label');
              if (wrappingLabel) chunks.push(wrappingLabel.innerText || wrappingLabel.textContent || '');
            } catch (_) {}
            try {
              let node = el.parentElement;
              for (let depth = 0; node && depth < 3; depth++, node = node.parentElement) {
                const text = (node.innerText || node.textContent || '').toString().replace(/\s+/g, ' ').trim();
                if (text && text.length <= 260) chunks.push(text);
              }
            } catch (_) {}
            try {
              const previous = el.previousElementSibling;
              if (previous) chunks.push(previous.innerText || previous.textContent || '');
            } catch (_) {}
            return norm(chunks.join(' '));
          };
          const fieldMeta = el => norm(meta(el) + ' ' + contextMeta(el));
          const editableInputs = () => (cfg.source === 'airline' ? deepQueryAll('input,textarea') : Array.from(document.querySelectorAll('input,textarea'))).filter(el => {
            const t = norm(el.type || 'text');
            return visible(el) && !el.disabled && !el.readOnly && ['text','tel','number','search',''].includes(t);
          });
          const isUnrelatedField = el => {
            const m = fieldMeta(el);
            return ['origin','destination','from airport','to airport','email','username','password','booking','flight number','site search','search site']
              .some(token => m.includes(token)) && !['awb','waybill','tracking id'].some(token => m.includes(token));
          };
          const findAWBField = () => {
            const all = editableInputs();
            let field = all.find(el => {
              const m = fieldMeta(el);
              return (m.includes('awb') || m.includes('air waybill') || m.includes('airwaybill') || m.includes('waybill')) && !m.includes('hawb');
            }) || null;

            if (!field && cfg.mode === 'airArabia') {
              field = all.find(el => fieldMeta(el).includes('tracking id')) || null;
            }
            if (!field && cfg.mode === 'trackTraceAuto') {
              field = all.find(el => {
                const m = fieldMeta(el);
                return (m.includes('enter number') || m.includes('tracking number') || m.includes('air cargo')) && !isUnrelatedField(el);
              }) || all.find(el => !isUnrelatedField(el)) || null;
            }
            if (!field && cfg.source === 'airline' && all.length <= 3) {
              field = all.find(el => {
                if (isUnrelatedField(el)) return false;
                const max = parseInt(el.getAttribute('maxlength') || '0', 10);
                const placeholderDigits = digits(el.getAttribute('placeholder') || '').length;
                return (max >= 8 && max <= 14) || placeholderDigits >= 8 || fieldMeta(el).includes('tracking');
              }) || null;
            }
            if (!field && cfg.source === 'transom') {
              // Transom currently renders AWB then HAWB. Never fall back to the HAWB input.
              field = all.find(el => !meta(el).includes('hawb')) || null;
            }
            return { field, all };
          };
          // Diagnostic-only snapshot for Transom. This tells us what Angular actually rendered
          // (formControlName, ng-valid/ng-invalid, masks, maxlength, etc.) without changing the
          // submission strategy. Keep it concise enough to survive WebKit -> Swift logging.
          const transomControlSummary = (el, index) => {
            try {
              const cls = (el.className || '').toString().replace(/\s+/g, ' ').trim();
              return [
                '#' + index,
                'tag=' + (el.tagName || ''),
                'type=' + (el.getAttribute('type') || ''),
                'id=' + (el.id || ''),
                'name=' + (el.name || ''),
                'formControl=' + (el.getAttribute('formcontrolname') || ''),
                'placeholder=' + (el.getAttribute('placeholder') || ''),
                'value=' + JSON.stringify((el.value || '').toString()),
                'maxlength=' + (el.getAttribute('maxlength') || ''),
                'pattern=' + (el.getAttribute('pattern') || ''),
                'required=' + (!!el.required),
                'disabled=' + (!!el.disabled),
                'readonly=' + (!!el.readOnly),
                'ariaInvalid=' + (el.getAttribute('aria-invalid') || ''),
                'htmlValid=' + (typeof el.checkValidity === 'function' ? el.checkValidity() : ''),
                'ngValid=' + (!!el.classList && el.classList.contains('ng-valid')),
                'ngInvalid=' + (!!el.classList && el.classList.contains('ng-invalid')),
                'ngTouched=' + (!!el.classList && el.classList.contains('ng-touched')),
                'ngDirty=' + (!!el.classList && el.classList.contains('ng-dirty')),
                'class=' + cls.slice(0, 220)
              ].join(' ');
            } catch (error) {
              return '#' + index + ' snapshot-error=' + String(error);
            }
          };
          const transomFormSummary = field => {
            try {
              const form = (field && field.form) || (field && field.closest ? field.closest('form') : null) || document.querySelector('form');
              if (!form) return 'form=<none>';
              const cls = (form.className || '').toString().replace(/\s+/g, ' ').trim();
              return [
                'tag=' + (form.tagName || ''),
                'id=' + (form.id || ''),
                'name=' + (form.getAttribute('name') || ''),
                'htmlValid=' + (typeof form.checkValidity === 'function' ? form.checkValidity() : ''),
                'ngValid=' + (!!form.classList && form.classList.contains('ng-valid')),
                'ngInvalid=' + (!!form.classList && form.classList.contains('ng-invalid')),
                'ngSubmitted=' + (!!form.classList && form.classList.contains('ng-submitted')),
                'class=' + cls.slice(0, 260)
              ].join(' ');
            } catch (error) { return 'form snapshot-error=' + String(error); }
          };
          const postTransomFormSnapshot = (stage, selectedField = null) => {
            if (cfg.source !== 'transom') return;
            try {
              const controls = Array.from(document.querySelectorAll('input,textarea,select'));
              const selectedIndex = selectedField ? controls.indexOf(selectedField) : -1;
              post('diagnostic', {
                stage,
                selectedIndex,
                controlCount: controls.length,
                controls: controls.slice(0, 12).map((el, index) => transomControlSummary(el, index)),
                formState: transomFormSummary(selectedField),
                href: location.href
              });
            } catch (error) {
              post('diagnostic', { stage: stage + '-snapshot-error', error: String(error), href: location.href });
            }
          };
          const findPrefixField = all => all.find(el => {
            const m = fieldMeta(el);
            return m.includes('prefix') || m.includes('airline code') || m.includes('carrier code') || m.includes('airline prefix');
          }) || null;

          // Diagnostic-only snapshot for non-Oman airline pages. Unlike Oman Air, the other
          // carriers currently share the generic adaptive adapter. These snapshots expose the
          // real DOM shape (or a cross-origin iframe boundary) so each carrier can be promoted
          // to a deterministic adapter instead of guessing selectors.
          const airlineElementSummary = (el, index) => {
            try {
              const label = norm(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || el.title || '');
              return [
                '#' + index,
                'tag=' + (el.tagName || ''),
                'type=' + (el.getAttribute('type') || ''),
                'id=' + (el.id || ''),
                'name=' + (el.name || ''),
                'placeholder=' + (el.getAttribute('placeholder') || ''),
                'aria=' + (el.getAttribute('aria-label') || ''),
                'formControl=' + (el.getAttribute('formcontrolname') || ''),
                'maxlength=' + (el.getAttribute('maxlength') || ''),
                'value=' + JSON.stringify((el.value || '').toString()).slice(0, 90),
                'text=' + JSON.stringify(label).slice(0, 130),
                'disabled=' + (!!el.disabled),
                'class=' + ((el.className || '').toString().replace(/\s+/g, ' ').trim()).slice(0, 180)
              ].join(' ');
            } catch (error) { return '#' + index + ' snapshot-error=' + String(error); }
          };
          const postAirlineDOMSnapshot = stage => {
            if (cfg.source !== 'airline') return;
            try {
              const inputs = editableInputs();
              const visibleActions = (cfg.source === 'airline' ? deepQueryAll('button,input[type="submit"],input[type="button"],[role="button"],a') : Array.from(document.querySelectorAll('button,input[type="submit"],input[type="button"],[role="button"],a'))).filter(visible);
              const forms = Array.from(document.querySelectorAll('form')).slice(0, 8).map((form, index) => {
                const cls = (form.className || '').toString().replace(/\s+/g, ' ').trim();
                return '#' + index + ' id=' + (form.id || '') + ' name=' + (form.getAttribute('name') || '') +
                  ' method=' + (form.getAttribute('method') || '') + ' action=' + (form.getAttribute('action') || '') +
                  ' htmlValid=' + (typeof form.checkValidity === 'function' ? form.checkValidity() : '') +
                  ' class=' + cls.slice(0, 180);
              });
              const frames = Array.from(document.querySelectorAll('iframe')).slice(0, 8).map((frame, index) =>
                '#' + index + ' id=' + (frame.id || '') + ' title=' + (frame.getAttribute('title') || '') +
                ' name=' + (frame.getAttribute('name') || '') + ' src=' + (frame.src || frame.getAttribute('src') || '').slice(0, 420)
              );
              post('diagnostic', {
                stage,
                prefix: cfg.prefix,
                mode: cfg.mode,
                inputCount: inputs.length,
                actionCount: visibleActions.length,
                formCount: forms.length,
                iframeCount: frames.length,
                inputs: inputs.slice(0, 14).map((el, index) => airlineElementSummary(el, index)),
                actions: visibleActions.slice(0, 16).map((el, index) => airlineElementSummary(el, index)),
                forms,
                iframes: frames,
                pageSample: pageText().replace(/\s+/g, ' ').slice(0, 700),
                href: location.href
              });
            } catch (error) {
              post('diagnostic', { stage: stage + '-snapshot-error', error: String(error), href: location.href });
            }
          };
          const actions = () => (cfg.source === 'airline' ? deepQueryAll('button,input[type="submit"],input[type="button"],[role="button"],a') : Array.from(document.querySelectorAll('button,input[type="submit"],input[type="button"],[role="button"],a'))).filter(visible);
          const actionLabel = el => norm(el && (el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || el.title));
          const findAction = () => {
            const all = actions();
            if (cfg.mode === 'trackTraceAuto') {
              const direct = all.find(el => actionLabel(el).includes('track direct'));
              if (direct) return direct;
              // After Track-Trace detects the airline it renders a carrier-specific `Track *` button.
              // Click that button rather than submitting the lookup form again (which only produces
              // `Reentry of tracking number required` and loops on the router page).
              const carrierTrack = all.find(el =>
                (el.tagName || '').toUpperCase() === 'BUTTON' && actionLabel(el).startsWith('track')
              );
              if (carrierTrack) return carrierTrack;
            }
            const preferred = [
              'track and trace', 'track direct', 'track shipment(s)', 'track shipment', 'track your shipment',
              'track your cargo', 'track cargo', 'track', 'search', 'submit', 'go'
            ];
            for (const token of preferred) {
              const exact = all.find(el => actionLabel(el) === token);
              if (exact) return exact;
            }
            return all.find(el => {
              const t = actionLabel(el);
              return t.includes('track and trace') || t.includes('track shipment') || t.includes('track your shipment') ||
                t.includes('track your cargo') || t.includes('track cargo');
            }) || null;
          };
          // Transom is deliberately stricter than the generic airline adapter. The production page
          // contains other Search/Submit controls, and pressing one of those can navigate the wrong
          // workflow. Never fall back to a generic button for Transom.
          const transomActions = () => Array.from(document.querySelectorAll(
            'button, a, input[type="submit"], input[type="button"]'
          )).filter(visible);
          const transomActionLabel = el => {
            if (!el) return '';
            let raw = (el.innerText || el.textContent || el.value || '').toString();
            // Angular Material renders the search icon as text (`search`) inside the same button.
            // Remove icon glyph text before comparing so `searchTrack and Trace` is treated as the
            // Track and Trace button, while a separate Search button is never eligible.
            try {
              Array.from(el.querySelectorAll('mat-icon,.material-icons,.mat-icon')).forEach(icon => {
                const iconText = (icon.innerText || icon.textContent || '').trim();
                if (iconText) raw = raw.replace(iconText, ' ');
              });
            } catch (_) {}
            return norm(raw.replace(/^search\s*/i, ''));
          };
          const findTransomTrackAction = () => transomActions().find(el =>
            transomActionLabel(el) === 'track and trace'
          ) || null;
          const nativeSetter = el => Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
          const dispatchInput = (el, data = null) => {
            try { el.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertText', data })); }
            catch (_) { el.dispatchEvent(new Event('input', { bubbles: true, composed: true })); }
            el.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
          };
          const clearField = el => {
            try {
              el.focus();
              const setter = nativeSetter(el);
              if (setter) setter.call(el, ''); else el.value = '';
              dispatchInput(el, null);
              return true;
            } catch (_) { return false; }
          };
          const setValue = (el, value) => {
            try {
              el.focus();
              const setter = nativeSetter(el);
              if (setter) setter.call(el, value); else el.value = value;
              dispatchInput(el, value);
              return digits(el.value).length > 0 || norm(el.value).length > 0;
            } catch (_) { return false; }
          };
          const pressEnter = el => {
            try {
              el.focus();
              el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
              el.dispatchEvent(new KeyboardEvent('keypress', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
              el.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
              return true;
            } catch (_) { return false; }
          };
          const airlineSelects = () => (cfg.source === 'airline' ? deepQueryAll('select') : Array.from(document.querySelectorAll('select'))).filter(visible);
          const setSelectValue = (select, value) => {
            try {
              const setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value')?.set;
              if (setter) setter.call(select, value); else select.value = value;
              select.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
              select.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
              return (select.value || '').toString() === (value || '').toString();
            } catch (_) { return false; }
          };
          const configureAirArabiaCarrier = () => {
            if (cfg.mode !== 'airArabia') return true;
            const selects = airlineSelects();
            for (const select of selects) {
              const options = Array.from(select.options || []);
              const match = options.find(option => {
                const token = norm((option.textContent || '') + ' ' + (option.value || ''));
                return token.includes('air arabia') || token === 'g9' || token.includes('514');
              });
              if (match && setSelectValue(select, match.value)) return true;

              const selectContext = fieldMeta(select);
              if (selectContext.includes('airline') || selectContext.includes('carrier')) {
                const firstNonEmpty = options.find(option => (option.value || '').toString().trim().length > 0);
                if (firstNonEmpty && setSelectValue(select, firstNonEmpty.value)) return true;
              }
            }
            // Some versions already fix Air Arabia and use unrelated dropdowns elsewhere on the page.
            // Do not mutate those controls; submitting the tracking ID remains safe.
            return true;
          };
          const configureAirIndiaCarrier = () => {
            if (cfg.mode !== 'airIndiaCargo') return true;

            // Current Air India Cargo public tracking page may render the airline code as either
            // a select or a separate editable control. Prefer an explicit Air India / AI / 098 option.
            const selects = airlineSelects();
            for (const select of selects) {
              const context = fieldMeta(select);
              const options = Array.from(select.options || []);
              const match = options.find(option => {
                const token = norm((option.textContent || '') + ' ' + (option.value || ''));
                return token.includes('air india') || token === 'ai' || token === '098' || token.includes('098');
              });
              if (match && (context.includes('airline') || context.includes('carrier') || context.includes('code') || options.length < 80)) {
                if (setSelectValue(select, match.value)) return true;
              }
            }

            // If there is a separate airline-code text field, fill it with the official 098 prefix.
            const controls = editableInputs();
            const prefixControl = findPrefixField(controls);
            if (prefixControl) {
              const existing = digits(prefixControl.value || '');
              if (existing === cfg.prefix) return true;
              return setValue(prefixControl, cfg.prefix);
            }

            // Some Air India variants preselect the carrier and expose only the AWB field.
            return true;
          };
          const genericInputValue = field => {
            if (cfg.mode === 'serialAWB') return { value: cfg.serial, strategy: 'serial-awb' };
            if (cfg.mode === 'trackTraceAuto') return { value: cfg.full, strategy: 'full-11-digit-awb' };

            const max = parseInt(field.getAttribute('maxlength') || '0', 10);
            const placeholder = field.getAttribute('placeholder') || '';
            const placeholderDigitCount = digits(placeholder).length;
            const fieldContext = fieldMeta(field);
            if (max > 0 && max <= 8) return { value: cfg.serial, strategy: 'serial-from-maxlength' };
            if (max === 11) return { value: cfg.full, strategy: 'full-from-maxlength' };
            if (placeholderDigitCount === 8 && !fieldContext.includes('prefix')) return { value: cfg.serial, strategy: 'serial-from-placeholder' };
            if (cfg.mode === 'airArabia') return { value: cfg.full, strategy: 'air-arabia-tracking-id' };
            if (cfg.mode === 'airIndiaCargo') return { value: cfg.full, strategy: 'air-india-full-awb' };
            return { value: cfg.formatted, strategy: 'formatted-awb' };
          };
          const typeDigitsLikeUser = async (el, value) => {
            try {
              clearField(el);
              await sleep(120);
              const setter = nativeSetter(el);
              let usedBrowserInsertion = false;
              for (let index = 0; index < value.length; index++) {
                const ch = value[index];
                el.focus();
                try {
                  const end = (el.value || '').length;
                  if (typeof el.setSelectionRange === 'function') el.setSelectionRange(end, end);
                } catch (_) {}

                const beforeCount = digits(el.value || '').length;
                try {
                  el.dispatchEvent(new KeyboardEvent('keydown', { key: ch, code: 'Digit' + ch, bubbles: true, cancelable: true }));
                  if (typeof document.execCommand === 'function') {
                    usedBrowserInsertion = document.execCommand('insertText', false, ch) || usedBrowserInsertion;
                  }
                } catch (_) {}
                await sleep(45);

                // If WebKit did not insert text through the editing command, fall back to the
                // native value setter for the raw digits typed so far, then emit the framework events.
                if (digits(el.value || '').length <= beforeCount) {
                  const typedSoFar = value.slice(0, index + 1);
                  if (setter) setter.call(el, typedSoFar); else el.value = typedSoFar;
                  try { el.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertText', data: ch })); }
                  catch (_) { el.dispatchEvent(new Event('input', { bubbles: true, composed: true })); }
                }
                try { el.dispatchEvent(new KeyboardEvent('keyup', { key: ch, code: 'Digit' + ch, bubbles: true, cancelable: true })); } catch (_) {}
                await sleep(45);
              }

              let ok = digits(el.value || '') === value;
              if (!ok) {
                // Last-resort value uses Transom's human-visible format, but still emits input/change.
                ok = setValue(el, cfg.spacedFormatted) && digits(el.value || '') === value;
              }
              el.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
              await sleep(180);
              el.blur();
              await sleep(700); // Let Angular form state and the input mask settle before finding the button.
              return { ok, usedBrowserInsertion, value: el.value || '' };
            } catch (_) { return { ok: false, usedBrowserInsertion: false, value: el.value || '' }; }
          };
          const actionIsEnabled = action => !!action && !action.disabled && norm(action.getAttribute('aria-disabled')) !== 'true';
          const clickAction = action => {
            try {
              if (!actionIsEnabled(action)) return false;
              action.scrollIntoView({ block: 'center', inline: 'center' });
              action.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true }));
              action.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
              action.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
              action.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
              return true;
            } catch (_) { return false; }
          };

          let ticks = 0;
          let submitted = false;
          let submitting = false;
          let attempt = 0;
          let lastSubmitTick = -100;
          let transomButtonMisses = 0;

          installTransomNetworkProbe();

          const submitTransom = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              const all = editableInputs();
              // The live Transom Angular form uses TWO controls for a master AWB:
              //   awbPrefix (maxlength=3) + awbNumber (maxlength=8).
              // Never put all 11 digits into awbPrefix: Angular keeps the form ng-invalid and
              // the submit handler exits before issuing any XHR/fetch request.
              const prefixField = all.find(el => norm(el.getAttribute('formcontrolname')) === 'awbprefix') || null;
              const numberField = all.find(el => norm(el.getAttribute('formcontrolname')) === 'awbnumber') || null;
              const hawb = all.find(el => norm(el.getAttribute('formcontrolname')) === 'hawb' || meta(el).includes('hawb')) || null;
              const field = prefixField;

              if (!prefixField || !numberField) {
                postTransomFormSnapshot('transom-dom-missing-split-awb-controls', field);
                post('diagnostic', {
                  stage: 'transom-form-wait', inputCount: all.length,
                  hasPrefixField: !!prefixField, hasNumberField: !!numberField, href: location.href
                });
                return false;
              }

              postTransomFormSnapshot('transom-dom-before-input', prefixField);

              // Fill exactly the values expected by Angular. Use the native HTMLInputElement setter
              // plus real input/change/blur events so Reactive Forms receives the changes.
              clearField(prefixField);
              clearField(numberField);
              if (hawb && (hawb.value || '').trim()) clearField(hawb);
              await sleep(120);

              const prefixSet = setValue(prefixField, cfg.prefix);
              prefixField.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
              prefixField.blur();
              await sleep(120);

              const numberSet = setValue(numberField, cfg.serial);
              numberField.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
              numberField.blur();
              if (hawb) hawb.blur();

              // Give Angular change detection time to move both controls and the parent form to ng-valid.
              let angularFormValid = false;
              let splitControlsValid = false;
              for (let i = 0; i < 15; i++) {
                const form = prefixField.form || numberField.form || prefixField.closest('form') || numberField.closest('form');
                const prefixInvalid = prefixField.classList && prefixField.classList.contains('ng-invalid');
                const numberInvalid = numberField.classList && numberField.classList.contains('ng-invalid');
                splitControlsValid = !prefixInvalid && !numberInvalid &&
                  digits(prefixField.value || '') === cfg.prefix && digits(numberField.value || '') === cfg.serial;
                angularFormValid = !!form && form.classList && form.classList.contains('ng-valid');
                if (splitControlsValid && angularFormValid) break;
                await sleep(150);
              }

              const filled = prefixSet && numberSet &&
                digits(prefixField.value || '') === cfg.prefix &&
                digits(numberField.value || '') === cfg.serial;
              const strategy = 'transom-split-controls';
              const typed = { ok: filled, usedBrowserInsertion: false, value: cfg.prefix + ' - ' + cfg.serial };
              postTransomFormSnapshot('transom-dom-after-input', prefixField);

              post('diagnostic', {
                stage: 'transom-split-state', attempt, strategy,
                prefixValue: prefixField.value || '', numberValue: numberField.value || '',
                prefixDigits: digits(prefixField.value || ''), numberDigits: digits(numberField.value || ''),
                splitControlsValid, angularFormValid,
                formClass: ((prefixField.form || numberField.form || prefixField.closest('form') || numberField.closest('form'))?.className || '').toString(),
                href: location.href
              });

              let action = findTransomTrackAction();
              // Angular/Material may render or enable Track and Trace one or two change-detection
              // cycles after blur. Wait for the exact action instead of selecting another button.
              for (let i = 0; i < 12 && (!action || !actionIsEnabled(action)); i++) {
                await sleep(200);
                action = findTransomTrackAction();
              }

              if (!action) {
                transomButtonMisses += 1;
                post('diagnostic', {
                  stage: 'track-button-not-found', attempt, strategy, filled,
                  awbValue: field.value || '', awbDigits: digits(field.value || ''),
                  href: location.href
                });
                attempt += 1;
                lastSubmitTick = ticks;
                if (transomButtonMisses >= 3) {
                  post('error', { code: 'track-button-not-found', href: location.href });
                }
                return false;
              }

              transomButtonMisses = 0;
              postTransomFormSnapshot('transom-dom-before-click', field);
              const enabled = actionIsEnabled(action);
              let clicked = false;
              if (filled && enabled && splitControlsValid && angularFormValid) {
                try {
                  action.scrollIntoView({ block: 'center', inline: 'center' });
                  action.click();
                  clicked = true;
                } catch (_) {}
              }
              if (clicked) {
                await sleep(250);
                postTransomFormSnapshot('transom-dom-after-click', field);
              }

              post('diagnostic', {
                stage: 'transom-submit', attempt, strategy, filled, clicked, enabled,
                usedBrowserInsertion: !!typed.usedBrowserInsertion,
                awbValue: cfg.prefix + ' - ' + cfg.serial, awbDigits: cfg.full,
                prefixValue: prefixField.value || '', numberValue: numberField.value || '',
                splitControlsValid, angularFormValid,
                fieldName: field.name || '', fieldID: field.id || '', formControl: field.getAttribute('formcontrolname') || '',
                formValid: field.form ? field.form.checkValidity() : null,
                actionText: action ? (action.innerText || action.textContent || action.value || '') : '',
                actionLabel: action ? transomActionLabel(action) : '',
                actionTag: action ? action.tagName : '', actionType: action ? (action.getAttribute('type') || '') : '',
                actionClass: action ? (action.className || '').toString().slice(0, 300) : '',
                actionDisabled: action ? !!action.disabled : null,
                ariaDisabled: action ? action.getAttribute('aria-disabled') : null,
                networkRequests: transomNetworkRequests,
                href: location.href
              });
              attempt += 1;
              submitted = submitted || clicked;
              lastSubmitTick = ticks;
              return clicked;
            } finally {
              submitting = false;
            }
          };

          const findEmiratesDocField = () => {
            const all = editableInputs();
            let field = all.find(el => {
              const m = meta(el);
              const placeholder = norm(el.getAttribute('placeholder'));
              return m.includes('doc. no') || m.includes('doc no') || m.includes('document no') ||
                placeholder.includes('17602268011') || placeholder.includes('doc. no');
            }) || null;
            if (!field) {
              // The eSkyCargo guest card renders Doc. No. as the first editable control above the
              // Search button. Do not fall back to Origin/Destination/date fields unless its nearby
              // container also carries the Doc. No. label.
              field = all.find(el => {
                try {
                  const parentText = norm((el.parentElement?.parentElement?.innerText || el.parentElement?.innerText || ''));
                  return parentText.includes('doc. no') && parentText.includes('search');
                } catch (_) { return false; }
              }) || null;
            }
            return { field, all };
          };
          const findEmiratesSearchAction = field => {
            const allActions = actions();
            if (field) {
              try {
                let node = field.parentElement;
                for (let depth = 0; node && depth < 5; depth++, node = node.parentElement) {
                  const local = Array.from(node.querySelectorAll('button,input[type="submit"],input[type="button"],[role="button"],a')).filter(visible);
                  const match = local.find(el => norm(el.innerText || el.value || el.getAttribute('aria-label') || el.title) === 'search');
                  if (match) return match;
                }
              } catch (_) {}
            }
            return allActions.find(el => norm(el.innerText || el.value || el.getAttribute('aria-label') || el.title) === 'search') || null;
          };
          const submitEmirates = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              postAirlineDOMSnapshot('emirates-dom-before-submit');
              const { field, all } = findEmiratesDocField();
              if (!field) {
                post('diagnostic', {
                  stage: 'emirates-doc-field-wait', inputCount: all.length,
                  href: location.href
                });
                return false;
              }

              clearField(field);
              await sleep(100);
              const filled = setValue(field, cfg.full) && digits(field.value || '') === cfg.full;
              // eSkyCargo tokenizes Doc. No. into a chip when Enter is pressed. Emit the same key
              // sequence after input/change; on versions that accept the raw text directly, this is
              // harmless and Search still sees the same document number.
              try {
                field.focus();
                field.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
                field.dispatchEvent(new KeyboardEvent('keypress', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
                field.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
              } catch (_) {}
              await sleep(500);

              let action = findEmiratesSearchAction(field);
              for (let i = 0; i < 10 && (!action || !actionIsEnabled(action)); i++) {
                await sleep(200);
                action = findEmiratesSearchAction(field);
              }
              const enabled = actionIsEnabled(action);
              const clicked = filled && enabled && clickAction(action);
              post('diagnostic', {
                stage: 'emirates-submit', filled, clicked, enabled,
                inputCount: all.length,
                fieldValue: field.value || '', fieldDigits: digits(field.value || ''),
                selectedField: airlineElementSummary(field, Math.max(0, all.indexOf(field))),
                selectedAction: action ? airlineElementSummary(action, 0) : '',
                href: location.href
              });
              if (clicked) {
                submitted = true;
                lastSubmitTick = ticks;
                await sleep(650);
                postAirlineDOMSnapshot('emirates-dom-after-click');
              }
              return clicked;
            } finally {
              submitting = false;
            }
          };

          const turkishContext = el => {
            if (!el) return '';
            const parts = [meta(el)];
            try {
              if (el.id) {
                const label = document.querySelector('label[for="' + CSS.escape(el.id) + '"]');
                if (label) parts.push(norm(label.innerText || label.textContent || ''));
              }
              let parent = el.parentElement;
              for (let i = 0; parent && i < 2; i++, parent = parent.parentElement) {
                parts.push(norm((parent.innerText || parent.textContent || '').slice(0, 220)));
              }
            } catch (_) {}
            return parts.join(' ');
          };
          const dismissTurkishCookies = () => {
            try {
              const action = actions().find(el => {
                const t = norm(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || '');
                return t === 'accept all' || t === 'accept all cookies';
              });
              if (action) {
                action.click();
                post('diagnostic', { stage: 'turkish-cookie-dismissed', href: location.href });
                return true;
              }
            } catch (_) {}
            return false;
          };
          const findTurkishAWBControls = () => {
            const all = Array.from(document.querySelectorAll('input,textarea')).filter(el => {
              const type = norm(el.type || 'text');
              return visible(el) && !el.disabled && ['text','tel','number','search',''].includes(type);
            });
            const prefixField = all.find(el => digits(el.value || '') === cfg.prefix) || all.find(el => {
              const m = meta(el);
              return m.includes('prefix') || m.includes('awbprefix');
            }) || null;
            let serialField = all.find(el => {
              if (el === prefixField) return false;
              const placeholder = norm(el.placeholder || '');
              if (placeholder.includes('up to 10 awb') || placeholder.includes('awb number')) return true;
              const c = turkishContext(el);
              return c.includes('awb no') || c.includes('awb number');
            }) || null;
            if (!serialField) serialField = all.find(el => el !== prefixField && !el.readOnly) || null;
            return { prefixField, serialField, all };
          };
          const findTurkishAddAction = () => {
            const wanted = 'add: ' + cfg.serial;
            const candidates = Array.from(document.querySelectorAll('button,a,[role="button"],[role="option"],li,div,span')).filter(visible);
            return candidates.find(el => {
              const t = norm(el.innerText || el.textContent || el.getAttribute('aria-label') || '');
              return t === wanted || t === ('add:' + cfg.serial) || t.startsWith(wanted);
            }) || null;
          };
          const findTurkishSearchAction = () => actions().find(el => {
            const t = norm(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || el.title || '');
            return t === 'search';
          }) || null;
          const submitTurkish = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              dismissTurkishCookies();
              postAirlineDOMSnapshot('turkish-dom-before-submit');
              const { prefixField, serialField, all } = findTurkishAWBControls();
              if (!serialField) {
                post('diagnostic', { stage: 'turkish-form-wait', inputCount: all.length, hasPrefixField: !!prefixField, href: location.href });
                return false;
              }
              let prefixOK = true;
              if (prefixField && digits(prefixField.value || '') !== cfg.prefix) {
                clearField(prefixField);
                prefixOK = setValue(prefixField, cfg.prefix) && digits(prefixField.value || '') === cfg.prefix;
              }
              clearField(serialField);
              await sleep(100);
              const serialOK = setValue(serialField, cfg.serial) && digits(serialField.value || '') === cfg.serial;
              try {
                serialField.focus();
                serialField.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
                serialField.dispatchEvent(new KeyboardEvent('keypress', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
                serialField.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
              } catch (_) {}
              await sleep(350);
              const addAction = findTurkishAddAction();
              if (addAction) {
                try { addAction.click(); } catch (_) {}
                await sleep(350);
              }
              let action = findTurkishSearchAction();
              for (let i = 0; i < 10 && (!action || !actionIsEnabled(action)); i++) {
                await sleep(200);
                action = findTurkishSearchAction();
              }
              const enabled = actionIsEnabled(action);
              const clicked = prefixOK && serialOK && enabled && clickAction(action);
              post('diagnostic', {
                stage: 'turkish-submit', prefixOK, serialOK, clicked, enabled,
                prefixValue: prefixField ? (prefixField.value || '') : cfg.prefix,
                serialValue: serialField.value || '', addActionFound: !!addAction,
                selectedAction: action ? airlineElementSummary(action, 0) : '', href: location.href
              });
              if (clicked) {
                submitted = true;
                lastSubmitTick = ticks;
                await sleep(650);
                postAirlineDOMSnapshot('turkish-dom-after-click');
              }
              return clicked;
            } finally { submitting = false; }
          };

          const qatarContext = el => {
            if (!el) return '';
            const parts = [meta(el)];
            try {
              let node = el;
              for (let depth = 0; node && depth < 4; depth++) {
                if (node.parentElement) {
                  node = node.parentElement;
                  parts.push(norm((node.innerText || node.textContent || '').slice(0, 260)));
                } else {
                  const root = node.getRootNode ? node.getRootNode() : null;
                  node = root && root.host ? root.host : null;
                  if (node) parts.push(norm((node.innerText || node.textContent || '').slice(0, 260)));
                }
              }
            } catch (_) {}
            return parts.join(' ');
          };
          const dismissQatarCookies = () => {
            try {
              const action = actions().find(el => {
                const t = norm(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || '');
                return t === 'yes, got it.' || t === 'yes, got it' || t === 'accept all' || t === 'accept';
              });
              if (action) {
                clickAction(action);
                post('diagnostic', { stage: 'qatar-cookie-dismissed', href: location.href });
                return true;
              }
            } catch (_) {}
            return false;
          };
          const findQatarMAWBControls = () => {
            const all = editableInputs();
            const prefixField = all.find(el => {
              const m = qatarContext(el);
              const value = digits(el.value || '');
              return value === cfg.prefix || m.includes('prefix');
            }) || null;
            let serialField = all.find(el => {
              if (el === prefixField) return false;
              const m = qatarContext(el);
              const placeholder = norm(el.getAttribute('placeholder') || '');
              return placeholder.includes('awb number') || placeholder.includes('awb no') ||
                m.includes('awb number(s)') || m.includes('awb number') || m.includes('mawb');
            }) || null;
            if (!serialField) {
              serialField = all.find(el => el !== prefixField && !el.readOnly && digits(el.value || '') !== cfg.prefix) || null;
            }
            return { prefixField, serialField, all };
          };
          const findQatarTrackAction = () => actions().find(el => {
            const t = norm(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || el.title || '');
            return t === 'track shipment(s)' || t === 'track shipments' || t === 'track shipment' || t.includes('track shipment');
          }) || null;
          const submitQatar = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              dismissQatarCookies();
              postAirlineDOMSnapshot('qatar-dom-before-submit');
              const { prefixField, serialField, all } = findQatarMAWBControls();
              if (!serialField) {
                post('diagnostic', {
                  stage: 'qatar-form-wait', inputCount: all.length, shadowRootCount: Math.max(0, deepRoots().length - 1),
                  hasPrefixField: !!prefixField, href: location.href
                });
                return false;
              }

              let prefixOK = true;
              if (prefixField && !prefixField.readOnly && digits(prefixField.value || '') !== cfg.prefix) {
                clearField(prefixField);
                prefixOK = setValue(prefixField, cfg.prefix) && digits(prefixField.value || '') === cfg.prefix;
              } else if (prefixField) {
                prefixOK = digits(prefixField.value || '') === cfg.prefix || norm(prefixField.value || '').includes(cfg.prefix);
              }

              let serialOK = digits(serialField.value || '') === cfg.serial;
              if (!serialOK) {
                clearField(serialField);
                await sleep(100);
                serialOK = setValue(serialField, cfg.serial) && digits(serialField.value || '') === cfg.serial;
              }
              try {
                serialField.dispatchEvent(new Event('blur', { bubbles: true, composed: true }));
                serialField.blur();
              } catch (_) {}
              await sleep(350);

              let action = findQatarTrackAction();
              for (let i = 0; i < 12 && (!action || !actionIsEnabled(action)); i++) {
                await sleep(180);
                action = findQatarTrackAction();
              }
              const enabled = actionIsEnabled(action);
              const clicked = prefixOK && serialOK && enabled && clickAction(action);
              post('diagnostic', {
                stage: 'qatar-submit', prefixOK, serialOK, clicked, enabled,
                inputCount: all.length, shadowRootCount: Math.max(0, deepRoots().length - 1),
                prefixValue: prefixField ? (prefixField.value || '') : cfg.prefix,
                serialValue: serialField.value || '',
                selectedField: airlineElementSummary(serialField, Math.max(0, all.indexOf(serialField))),
                selectedAction: action ? airlineElementSummary(action, 0) : '', href: location.href
              });
              if (clicked) {
                submitted = true;
                lastSubmitTick = ticks;
                await sleep(700);
                postAirlineDOMSnapshot('qatar-dom-after-click');
              }
              return clicked;
            } finally { submitting = false; }
          };

          const findAirIndiaAWBField = () => {
            const all = editableInputs();
            const exact = all.find(el => norm(el.id) === 'shipmentvalue' || norm(el.getAttribute('name')) === 'shipmentvalue');
            if (exact) return { field: exact, all };
            const fallback = all.find(el => {
              const context = fieldMeta(el);
              return context.includes('enter the awb number') || context.includes('awb number');
            }) || null;
            return { field: fallback, all };
          };
          const findAirIndiaNextAction = () => actions().find(el => actionLabel(el) === 'next') || null;
          const submitAirIndia = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              postAirlineDOMSnapshot('air-india-dom-before-submit');
              const { field, all } = findAirIndiaAWBField();
              if (!field) {
                post('diagnostic', {
                  stage: 'air-india-form-wait', inputCount: all.length,
                  iframeCount: document.querySelectorAll('iframe').length,
                  href: location.href
                });
                return false;
              }

              let filled = digits(field.value || '') === cfg.full;
              if (!filled) {
                clearField(field);
                await sleep(100);
                filled = setValue(field, cfg.full) && digits(field.value || '') === cfg.full;
              }
              try {
                field.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
                field.dispatchEvent(new Event('blur', { bubbles: true, composed: true }));
                field.blur();
              } catch (_) {}

              // The portal enables Next only after its React/Bootstrap state receives the AWB input.
              let action = findAirIndiaNextAction();
              for (let i = 0; i < 20 && (!action || !actionIsEnabled(action)); i++) {
                await sleep(180);
                action = findAirIndiaNextAction();
              }
              const enabled = actionIsEnabled(action);
              const clicked = filled && enabled && clickAction(action);
              let enterFallback = false;
              if (filled && !clicked && !action) enterFallback = pressEnter(field);

              post('diagnostic', {
                stage: 'air-india-submit', filled, clicked, enabled, enterFallback,
                strategy: 'air-india-full-awb-next',
                fieldValue: field.value || '', fieldDigits: digits(field.value || ''),
                selectedField: airlineElementSummary(field, Math.max(0, all.indexOf(field))),
                selectedAction: action ? airlineElementSummary(action, 0) : '',
                href: location.href
              });
              if (clicked || enterFallback) {
                submitted = true;
                lastSubmitTick = ticks;
                await sleep(700);
                postAirlineDOMSnapshot('air-india-dom-after-next');
              }
              return clicked || enterFallback;
            } finally {
              submitting = false;
            }
          };

          const submitGenericAirline = async () => {
            if (submitting) return false;
            submitting = true;
            try {
              postAirlineDOMSnapshot('airline-dom-before-submit');
              const { field, all } = findAWBField();
              const prefixField = findPrefixField(all);
              if (!field) {
                post('diagnostic', {
                  stage: 'form-wait', inputCount: all.length, iframeCount: document.querySelectorAll('iframe').length,
                  href: location.href,
                  isMainFrame: (() => { try { return window.top === window; } catch (_) { return false; } })(),
                  frameName: window.name || ''
                });
                postAirlineDOMSnapshot('airline-form-not-found');
                return false;
              }

              const carrierReady = configureAirArabiaCarrier() && configureAirIndiaCarrier();
              let filled = false;
              let strategy = 'formatted-awb';
              if ((cfg.mode === 'prefixAndSerial' || cfg.mode === 'adaptive' || cfg.mode === 'airIndiaCargo') && prefixField && prefixField !== field) {
                strategy = 'prefix-and-serial';
                filled = setValue(prefixField, cfg.prefix) && setValue(field, cfg.serial);
              } else {
                const input = genericInputValue(field);
                strategy = input.strategy;
                filled = setValue(field, input.value);
              }

              await sleep(350);
              let action = findAction();
              for (let i = 0; i < 5 && action && !actionIsEnabled(action); i++) {
                await sleep(180);
                action = findAction();
              }
              const enabled = actionIsEnabled(action);
              let clicked = filled && carrierReady && enabled && clickAction(action);
              let submittedByForm = false;
              let enterFallback = false;

              if (filled && carrierReady && !clicked) {
                try {
                  const form = field.form || (field.closest && field.closest('form'));
                  if (form && typeof form.requestSubmit === 'function') {
                    form.requestSubmit();
                    submittedByForm = true;
                  } else if (form && typeof form.submit === 'function') {
                    form.submit();
                    submittedByForm = true;
                  }
                } catch (_) {}
              }
              if (filled && carrierReady && !clicked && !submittedByForm) {
                enterFallback = pressEnter(field);
              }

              const didSubmit = clicked || submittedByForm || enterFallback;
              post('diagnostic', {
                stage: 'submit', filled, carrierReady, clicked, submittedByForm, enterFallback, enabled, strategy, inputCount: all.length,
                selectedField: airlineElementSummary(field, Math.max(0, all.indexOf(field))),
                prefixField: prefixField ? airlineElementSummary(prefixField, Math.max(0, all.indexOf(prefixField))) : '',
                selectedAction: action ? airlineElementSummary(action, 0) : '',
                href: location.href,
                isMainFrame: (() => { try { return window.top === window; } catch (_) { return false; } })(),
                frameName: window.name || ''
              });
              if (didSubmit) {
                await sleep(500);
                postAirlineDOMSnapshot('airline-dom-after-submit');
              }
              submitted = submitted || didSubmit;
              lastSubmitTick = ticks;
              return didSubmit;
            } finally {
              submitting = false;
            }
          };

          const transomDOMLooksComplete = text => {
            const l = norm(text);
            const markers = ['awb details','received pieces','freight information','events status'];
            const markerCount = markers.filter(token => l.includes(token)).length;
            const hasOperationalEvent = ['document released','shipment ready for delivery','flight arrival']
              .some(token => l.includes(token));
            let rowCount = 0;
            try { rowCount = document.querySelectorAll('tr').length; } catch (_) {}
            return markerCount >= 2 && (hasOperationalEvent || rowCount >= 5);
          };

          let emiratesDetailExpandAttempts = 0;
          let emiratesDetailExpandAt = 0;
          const emiratesDOMLooksComplete = text => {
            const l = norm(text);
            if (!l.includes('search results') || !awbVisible(text)) return false;
            // "Gross Weight" is specific to the shipment result card. The Find Offers form below
            // only says "Weight", so this cannot be satisfied by the empty search form controls.
            const hasGrossWeight = l.includes('gross weight');
            const hasPiecesValue = /\bpieces\s+\d{1,5}\b/i.test(text.replace(/\s+/g, ' '));
            return hasGrossWeight && hasPiecesValue;
          };
          const expandEmiratesDetailsIfNeeded = text => {
            if (cfg.mode !== 'emiratesDocNumber' || emiratesDOMLooksComplete(text)) return false;
            const l = norm(text);
            if (!l.includes('search results') || !awbVisible(text)) return false;
            if (emiratesDetailExpandAttempts >= 4) return false;
            if (emiratesDetailExpandAt && (Date.now() - emiratesDetailExpandAt) < 650) return false;

            const candidates = Array.from(document.querySelectorAll('button,a,[role="button"],div,span')).filter(visible);
            const action = candidates.find(el => {
              const label = norm(el.innerText || el.textContent || el.getAttribute('aria-label') || el.title || '');
              return label.startsWith('show details') || label.startsWith('view details') ||
                label.startsWith('more details') || label.startsWith('shipment details') ||
                label.startsWith('show detail') || label.startsWith('view detail');
            });
            if (!action) return false;
            emiratesDetailExpandAttempts += 1;
            emiratesDetailExpandAt = Date.now();
            try {
              action.scrollIntoView({ block: 'center', inline: 'nearest' });
              action.click();
              post('diagnostic', {
                stage: 'emirates-details-expand', attempt: emiratesDetailExpandAttempts,
                actionText: (action.innerText || action.textContent || '').trim().slice(0, 120),
                href: location.href
              });
              return true;
            } catch (_) { return false; }
          };

          const turkishDOMLooksComplete = text => {
            const l = norm(text);
            if (!awbVisible(text)) return false;
            const flat = text.replace(/\s+/g, ' ');
            const hasPieces = /\b\d{1,5}\s+piece\(s\)/i.test(flat);
            const hasWeight = /\b[\d,.]+\s*kg\b/i.test(flat);
            const hasRoute = /\bFrom\s+[A-Z]{3}\b/i.test(flat) && /\bTo\s+[A-Z]{3}\b/i.test(flat);
            const hasStatus = ['in transit','delivered','ready for delivery','arrived','departed','received','accepted']
              .some(token => l.includes(token));
            return hasPieces && hasWeight && hasRoute && hasStatus;
          };

          const qatarDOMLooksComplete = text => {
            const l = norm(text);
            if (!awbVisible(text)) return false;
            const flat = text.replace(/\s+/g, ' ');
            const hasPieces = /\b\d{1,5}\s*(?:piece\(s\)|pcs)\b/i.test(flat);
            const hasWeight = /\b[\d,.]+\s*kg\b/i.test(flat);
            const hasTimeline = ['delivered','notified consignee','received at destination','received in','arrived in','departed from']
              .some(token => l.includes(token));
            return hasPieces && hasWeight && hasTimeline;
          };

          const inspect = () => {
            const text = pageText();
            if (!hasResultEvidence(text)) return false;

            if (cfg.mode === 'emiratesDocNumber' && !hasNoData(text)) {
              // eSkyCargo first paints a compact result header (status + route) and only then exposes
              // Pieces/Gross Weight in its detail section. Previous builds returned at the compact
              // header, which is why the native card was LIVE but missing those fields.
              if (!emiratesDOMLooksComplete(text)) {
                expandEmiratesDetailsIfNeeded(text);
                return false;
              }
              post('diagnostic', {
                stage: 'emirates-dom-complete', detailExpandAttempts: emiratesDetailExpandAttempts,
                textLength: resultText().length, href: location.href
              });
              post('result', { text: resultText(), href: location.href, transport: 'emirates-rendered-details' });
              return true;
            }

            if (cfg.mode === 'turkishAWBToken' && !hasNoData(text)) {
              if (!turkishDOMLooksComplete(text)) return false;
              post('diagnostic', { stage: 'turkish-dom-complete', textLength: resultText().length, href: location.href });
              post('result', { text: resultText(), href: location.href, transport: 'turkish-rendered-details' });
              return true;
            }

            if (cfg.mode === 'qatarMAWB' && !hasNoData(text)) {
              if (!qatarDOMLooksComplete(text)) return false;
              post('diagnostic', {
                stage: 'qatar-dom-complete', textLength: resultText().length,
                shadowRootCount: Math.max(0, deepRoots().length - 1), href: location.href
              });
              post('result', { text: resultText(), href: location.href, transport: 'qatar-rendered-timeline' });
              return true;
            }

            if (cfg.source !== 'transom' || hasNoData(text)) {
              post('result', { text: resultText(), href: location.href });
              return true;
            }

            // Angular paints the Transom result progressively. In V4.1.3 we returned as soon as the
            // first heading appeared, which could tear down WKWebView before Received Pieces / Events
            // tables were populated. Wait for a complete, stable snapshot instead.
            const now = Date.now();
            if (!transomEvidenceSince) transomEvidenceSince = now;
            const snapshot = resultText();
            if (snapshot === transomLastResultText) transomStableReads += 1;
            else { transomLastResultText = snapshot; transomStableReads = 0; }

            const complete = transomDOMLooksComplete(text);
            const waited = now - transomEvidenceSince;
            if ((complete && (transomStableReads >= 2 || waited >= 1800)) || waited >= 4200) {
              post('diagnostic', {
                stage: 'transom-dom-complete', complete, stableReads: transomStableReads,
                waitedMs: waited, textLength: snapshot.length, href: location.href
              });
              post('result', { text: snapshot, href: location.href, transport: 'rendered-dom' });
              return true;
            }
            return false;
          };

          const observer = new MutationObserver(() => { inspect(); });
          try { observer.observe(document.documentElement || document.body, { subtree: true, childList: true, characterData: true, attributes: true }); } catch (_) {}
          post('diagnostic', {
            stage: 'installed', source: cfg.source, mode: cfg.mode, href: location.href,
            isMainFrame: (() => { try { return window.top === window; } catch (_) { return false; } })(),
            frameName: window.name || ''
          });
          if (cfg.source === 'airline') {
            setTimeout(() => postAirlineDOMSnapshot('airline-dom-installed'), 900);
          }

          const timer = setInterval(async () => {
            ticks += 1;
            if (inspect()) {
              clearInterval(timer);
              try { observer.disconnect(); } catch (_) {}
              return;
            }

            if (cfg.source === 'transom') {
              // Wait for Angular hydration. The normal path submits once. If the exact Track and Trace
              // click produced *no* XHR/fetch at all for six seconds, retry the same split AWB controls once.
              // Never fall back to Search, Submit, Enter, or another control.
              if (!submitted && ticks >= 2) await submitTransom();
              else if (submitted && transomNetworkRequests === 0 && attempt < 2 && (ticks - lastSubmitTick) >= 12) {
                submitted = false;
                await submitTransom();
              }
            } else if (cfg.mode !== 'queryPrepared' || ticks >= 4) {
              if (!submitted && !submitting) {
                if (cfg.mode === 'emiratesDocNumber') await submitEmirates();
                else if (cfg.mode === 'turkishAWBToken') await submitTurkish();
                else if (cfg.mode === 'qatarMAWB') {
                  // Give the official documentNumber/documentPrefix deep link a short head start.
                  // If Salesforce does not auto-hydrate it, use the visible guest form through any
                  // open LWC ShadowRoots rather than falling back to the generic light-DOM adapter.
                  if (ticks >= 6) await submitQatar();
                }
                else if (cfg.mode === 'airIndiaCargo') await submitAirIndia();
                else await submitGenericAirline();
              }
            }

            // Only use the captured network body if the rendered DOM never becomes usable.
            // Give Angular several seconds to finish painting its richer result first.
            if (cfg.source === 'transom' && transomNetworkFallbackText && transomNetworkFallbackAt &&
                (Date.now() - transomNetworkFallbackAt) >= 5000 && !transomEvidenceSince) {
              post('diagnostic', { stage: 'transom-network-fallback-used', href: location.href });
              post('result', { text: transomNetworkFallbackText, href: location.href, transport: 'network-fallback' });
              clearInterval(timer);
              try { observer.disconnect(); } catch (_) {}
              return;
            }

            if (ticks % 10 === 0) {
              const text = pageText();
              post('diagnostic', {
                stage: 'poll', ticks, submitted, attempt, textLength: text.length,
                networkRequests: transomNetworkRequests, networkResponses: transomNetworkResponses,
                pageSample: cfg.source === 'transom' ? text.replace(/\s+/g, ' ').slice(0, 500) : '',
                href: location.href
              });
              if (cfg.source === 'airline' && (!submitted || ticks === 10 || ticks === 30)) {
                postAirlineDOMSnapshot('airline-dom-poll-' + ticks);
              }
            }
            // The newly-covered airline portals are best-effort attempts with deterministic fallbacks.
            // Cap each one at ~14s so a changed website cannot hold the progressive UI for 45–52s.
            // Keep the four already-verified adapters on their proven timing windows.
            const fastCarrierAttempt = cfg.source === 'airline' &&
              !['emiratesDocNumber','turkishAWBToken','qatarMAWB','airIndiaCargo'].includes(cfg.mode) &&
              !(cfg.mode === 'queryPrepared' && cfg.prefix === '910');
            const maxTicks = fastCarrierAttempt ? 28 : ((cfg.source === 'airline' && cfg.mode === 'qatarMAWB') ? 44 : ((cfg.source === 'airline' && cfg.mode === 'airIndiaCargo') ? 56 : 90));
            if (ticks >= maxTicks) {
              clearInterval(timer);
              try { observer.disconnect(); } catch (_) {}
              post('timeout', { text: resultText(), href: location.href });
            }
          }, 500);
        })();
        """#
    }

    private static func javaScriptString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8),
              array.count >= 2 else {
            return "\"\""
        }
        return String(array.dropFirst().dropLast())
    }
}

@MainActor
private enum OfficialTrackingPageReader {
    /// WebKit is intentionally serialized. Two simultaneous hidden WKWebViews caused unstable content
    /// process behavior on the user's device in V3.9. Reliability is more important than shaving a few seconds.
    private static let gate = TrackingWebKitSerialGate()

    static func read(
        url: URL,
        prefix: String,
        serial: String,
        fullAWB: String,
        source: TrackingWebSource,
        mode: TrackingAutomationMode
    ) async throws -> String {
        try await gate.withLock {
            let worker = TrackingPageWorker(
                url: url,
                prefix: prefix,
                serial: serial,
                fullAWB: fullAWB,
                source: source,
                mode: mode
            )
            return try await worker.run()
        }
    }
}

@MainActor
private final class TrackingWebKitSerialGate {
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withLock<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
        if busy {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        busy = true
        defer {
            busy = false
            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            }
        }
        return try await operation()
    }
}

@MainActor
private final class TrackingPageWorker: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let url: URL
    private let prefix: String
    private let serial: String
    private let fullAWB: String
    private let source: TrackingWebSource
    private let mode: TrackingAutomationMode

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?
    private var hasFinished = false
    private var latestDiagnostic = ""

    init(url: URL, prefix: String, serial: String, fullAWB: String, source: TrackingWebSource, mode: TrackingAutomationMode) {
        self.url = url
        self.prefix = prefix
        self.serial = serial
        self.fullAWB = fullAWB
        self.source = source
        self.mode = mode
    }

    func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = WKUserContentController()
            controller.add(self, name: "trackingBridge")
            controller.addUserScript(WKUserScript(
                source: TrackingWebAutomation.injectedScript(
                    prefix: prefix,
                    serial: serial,
                    fullAWB: fullAWB,
                    source: source,
                    mode: mode
                ),
                injectionTime: .atDocumentEnd,
                // Airline portals often mount the public tracker inside a same- or cross-origin frame.
                // Inject the *same one-shot user script* into each airline frame so the bridge runs
                // locally there; this does not traverse iframe DOM or revive V3.9's repeated JS polling.
                // Transom stays main-frame-only because its Angular page is already deterministic.
                forMainFrameOnly: source == .transom
            ))

            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.userContentController = controller

            // Keep a real iPhone-sized viewport. Transom is an Angular SPA and needs several seconds
            // after Track and Trace to paint its operational tables. An off-screen WKWebView
            // (x = -1200) was being treated as idle by iOS on the user's device, so its WebContent/GPU
            // process could exit after the request but before Events Status / Received Pieces rendered.
            // The view is attached inside the real window below with very low alpha and no interaction.
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
            if source == .transom {
                webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            }
            webView.navigationDelegate = self
            webView.alpha = source == .transom ? 0.015 : 0.01
            webView.isUserInteractionEnabled = false
            webView.accessibilityElementsHidden = true
            webView.scrollView.isScrollEnabled = false
            self.webView = webView

            // Keep the web view inside the real visible window. Being attached but positioned far
            // off-screen was not enough for Transom: iOS could still idle-exit the WebContent/GPU
            // process while Angular was painting the result. A nearly-transparent, non-interactive
            // full viewport keeps rendering alive without blocking the app UI.
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
               let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                webView.frame = window.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 390, height: 844) : window.bounds
                webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                window.addSubview(webView)
            }

            var request = URLRequest(url: url)
            let fastCarrierAttempt = source == .airline &&
                mode != .emiratesDocNumber &&
                mode != .turkishAWBToken &&
                mode != .qatarMAWB &&
                !(mode == .queryPrepared && prefix == "910")
            request.timeoutInterval = fastCarrierAttempt ? 14 : 25
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            webView.load(request)

            Task { @MainActor [weak self] in
                let watchdogSeconds: Int64 = fastCarrierAttempt ? 16 : 52
                try? await Task.sleep(for: .seconds(watchdogSeconds))
                guard let self, !self.hasFinished else { return }
                #if DEBUG
                if !self.latestDiagnostic.isEmpty { print("[TrackingWeb][timeout] \(self.latestDiagnostic)") }
                #endif
                self.finish(.failure(OfficialWebTrackingError.timedOut))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(OfficialWebTrackingError.pageLoadFailed))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(OfficialWebTrackingError.pageLoadFailed))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !hasFinished, message.name == "trackingBridge",
              let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else { return }

        switch kind {
        case "result":
            guard let text = body["text"] as? String else { return }
            if TrackingWebResultDetector.hasEvidence(text: text, awb: fullAWB, source: source) {
                finish(.success(text))
            }
        case "diagnostic":
            latestDiagnostic = String(describing: body)
            #if DEBUG
            print("[TrackingWeb][\(source.rawValue)] \(latestDiagnostic)")
            #endif
        case "error":
            if let code = body["code"] as? String, code == "track-button-not-found" {
                finish(.failure(OfficialWebTrackingError.formNotFound))
            } else {
                finish(.failure(OfficialWebTrackingError.noLiveDataFound))
            }
        case "timeout":
            // `inspect()` runs immediately before each script timer deadline and would already have
            // emitted a real result. In all-frame airline mode, ignore local timeout messages entirely:
            // an irrelevant shell frame must not cancel (or fabricate no-data for) a useful sibling frame.
            // The worker watchdog owns the final failure a couple of seconds later.
            break
        default:
            break
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard !hasFinished else { return }
        hasFinished = true
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "trackingBridge")
        webView?.removeFromSuperview()
        webView = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}

public enum TrackingSourceTextParser {
    public static func airlineSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        if airlinePrefix == "176", let emirates = emiratesSkyCargoSnapshot(
            from: text,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            sourceURL: sourceURL
        ) {
            return emirates
        }

        if airlinePrefix == "235", let turkish = turkishCargoSnapshot(
            from: text,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            sourceURL: sourceURL
        ) {
            return turkish
        }

        if airlinePrefix == "157", let qatar = qatarCargoSnapshot(
            from: text,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            sourceURL: sourceURL
        ) {
            return qatar
        }

        if airlinePrefix == "098", let airIndia = airIndiaCargoSnapshot(
            from: text,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            sourceURL: sourceURL
        ) {
            return airIndia
        }

        if let smartKargo = smartKargoSnapshot(
            from: text,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            sourceURL: sourceURL
        ) {
            return smartKargo
        }

        let collapsed = collapseWhitespace(text)
        let routePair = regexGroups(#"\b([A-Z]{3})\s*(?:->|→|–|—|-)\s*([A-Z]{3})\b"#, in: collapsed.uppercased(), caseInsensitive: false)
        let recentEvents = genericRecentAirlineEvents(from: text)

        var flight = firstValue(in: text, labels: ["flight number", "flight no", "flight"])
        if flight == nil, let groups = regexGroups(#"\b([A-Z][A-Z0-9]|[0-9][A-Z])\s?(\d{3,4})\b"#, in: collapsed.uppercased(), caseInsensitive: false), groups.count == 2 {
            flight = groups[0] + groups[1]
        }

        var origin = airportCode(from: firstValue(in: text, labels: ["origin", "orig"]))
        var destination = airportCode(from: firstValue(in: text, labels: ["destination", "dest"]))
        if origin == nil, routePair?.count == 2 { origin = routePair?[0] }
        if destination == nil, routePair?.count == 2 { destination = routePair?[1] }

        var departure = firstValue(in: text, labels: ["departure", "departed", "dep date", "departure date"])
        var arrival = firstValue(in: text, labels: ["arrival", "arrived", "arrival date"])
        if departure == nil { departure = recentEvents?.first(where: { $0.title.lowercased().contains("depart") })?.timestamp }
        if arrival == nil { arrival = recentEvents?.first(where: { $0.title.lowercased().contains("arriv") || $0.title.lowercased().contains("received at destination") })?.timestamp }

        var pieces = integer(from: firstValue(in: text, labels: ["total pieces", "pieces", "piece(s)", "pcs"]))
        if pieces == nil, let raw = regexGroups(#"\b(\d{1,5})\s*(?:piece\(s\)|pieces?|pcs)\b"#, in: collapsed, caseInsensitive: true)?.first {
            pieces = Int(raw)
        }

        var weight = decimal(from: firstValue(in: text, labels: ["gross weight", "total weight", "weight"] ))
        if weight == nil, let raw = regexGroups(#"\b([\d,.]+)\s*kg\b"#, in: collapsed, caseInsensitive: true)?.first {
            weight = Decimal(string: raw.replacingOccurrences(of: ",", with: ""))
        }

        var status = firstValue(in: text, labels: ["shipment status", "current status", "status"])
        if status == nil { status = recentEvents?.first?.title }
        var lastEvent = firstValue(in: text, labels: ["last event", "latest event", "latest status", "event"])
        if lastEvent == nil, let event = recentEvents?.first {
            lastEvent = [event.code, event.title, event.location, event.timestamp].compactMap { $0 }.joined(separator: " — ")
        }

        let meaningfulValues: [Any?] = [flight, origin, destination, pieces, weight, status, lastEvent]
        guard meaningfulValues.contains(where: { $0 != nil }) else { return nil }

        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: cleanedTechnicalValue(flight),
            origin: origin,
            destination: destination,
            departure: cleanedDisplayValue(departure),
            arrival: cleanedDisplayValue(arrival),
            pieces: pieces,
            weightKg: weight,
            status: cleanedDisplayValue(status),
            lastEvent: cleanedDisplayValue(lastEvent),
            recentEvents: recentEvents,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func airIndiaCargoSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        guard lower.contains("awb activity timeline") ||
                (lower.contains("delivered") && lower.contains("manifested") && lower.contains("accepted")) else {
            return nil
        }

        let events = airIndiaRecentEvents(from: text)
        guard let latest = events?.first else { return nil }

        let pieces: Int? = {
            if let raw = regexGroups(#"\b(\d{1,5})\s*(?:pcs|pieces?)\b"#, in: collapsed, caseInsensitive: true)?.first {
                return Int(raw)
            }
            return nil
        }()
        let weight: Decimal? = {
            guard let raw = regexGroups(#"\b([\d,.]+)\s*kg\b"#, in: collapsed, caseInsensitive: true)?.first else { return nil }
            return Decimal(string: raw.replacingOccurrences(of: ",", with: ""))
        }()

        let destinationEvent = events?.first(where: { event in
            let title = event.title.lowercased()
            return title.contains("delivered") || title.contains("arrived") || title.contains("consignee notified")
        })
        let departureEvent = events?.first(where: { $0.title.lowercased().contains("departed") })
        let oldestOriginEvent = events?.reversed().first(where: { event in
            let title = event.title.lowercased()
            return title.contains("accepted") || title.contains("manifested") || title.contains("departed")
        })

        let origin = oldestOriginEvent?.location ?? departureEvent?.location
        let destination = destinationEvent?.location ?? events?.first(where: { $0.title.lowercased().contains("arrived") })?.location
        let flight = events?.first(where: { $0.flightNumber != nil })?.flightNumber
        let lastEvent = [latest.code, latest.title, latest.location, latest.timestamp].compactMap { $0 }.joined(separator: " — ")

        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: cleanedTechnicalValue(flight),
            origin: cleanedTechnicalValue(origin)?.uppercased(),
            destination: cleanedTechnicalValue(destination)?.uppercased(),
            departure: departureEvent?.timestamp,
            arrival: events?.first(where: { $0.title.lowercased().contains("arrived") })?.timestamp,
            pieces: pieces,
            weightKg: weight,
            status: latest.title,
            lastEvent: lastEvent,
            recentEvents: events,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func airIndiaRecentEvents(from text: String) -> [TrackingEvent]? {
        let rawLines = text.components(separatedBy: .newlines)
            .map(collapseWhitespace)
            .filter { !$0.isEmpty }
        let definitions: [(needle: String, code: String, title: String)] = [
            ("consignee notified", "NTF", "Consignee Notified"),
            ("broken down", "BRK", "Broken Down"),
            ("delivered", "DLV", "Delivered"),
            ("arrived", "ARR", "Arrived"),
            ("departed", "DEP", "Departed"),
            ("manifested", "MAN", "Manifested"),
            ("accepted", "RCS", "Accepted")
        ]

        var output: [TrackingEvent] = []
        var seen = Set<String>()
        for index in rawLines.indices {
            let line = rawLines[index]
            let lower = line.lowercased()
            guard let definition = definitions.first(where: { lower.contains($0.needle) }) else { continue }

            let contextEnd = min(rawLines.count, index + 3)
            let context = rawLines[index..<contextEnd].joined(separator: " ")
            let timestamp = regexAllMatches(
                #"\b\d{1,2}\s+[A-Za-z]{3}\s+\d{4},?\s+\d{2}:\d{2}(?::\d{2})?\b"#,
                in: context,
                caseInsensitive: true
            ).first
            let location = regexGroups(#"\b(?:at\s+)?([A-Z]{3})\b"#, in: line, caseInsensitive: false)?.first
                ?? regexGroups(#"^([A-Z]{3})\b"#, in: context, caseInsensitive: false)?.first
            let flight = regexAllMatches(#"\b[A-Z0-9]{2}[- ]?\d{2,4}\b"#, in: line, caseInsensitive: true).last?
                .replacingOccurrences(of: " ", with: "")
                .uppercased()

            let key = [definition.code, definition.title, location ?? "", timestamp ?? ""].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            output.append(TrackingEvent(
                code: definition.code,
                title: definition.title,
                location: location?.uppercased(),
                timestamp: timestamp,
                flightNumber: flight
            ))
        }
        return normalizedRecentEvents(output)
    }

    private static func normalizedRecentEvents(_ events: [TrackingEvent]) -> [TrackingEvent]? {
        var seen = Set<String>()
        var output: [TrackingEvent] = []
        for event in events {
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let key = [event.code ?? "", title.lowercased(), event.location ?? "", event.timestamp ?? ""].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            output.append(TrackingEvent(
                code: cleanedDisplayValue(event.code)?.uppercased(),
                title: title,
                location: cleanedDisplayValue(event.location)?.uppercased(),
                timestamp: cleanedDisplayValue(event.timestamp),
                flightNumber: cleanedTechnicalValue(event.flightNumber)?.uppercased()
            ))
        }
        guard !output.isEmpty else { return nil }
        return TrackingEventTimestamp.newestFirst(output)
    }

    /// Generic event extraction used by every live airline adapter. It only promotes text that is
    /// visibly present on the official source; it never invents a missing milestone.
    private static func genericRecentAirlineEvents(from text: String) -> [TrackingEvent]? {
        let known: [(needle: String, code: String?, title: String)] = [
            ("shipment notified for delivery", "NFD", "Shipment Notified For Delivery"),
            ("notified consignee", "NFD", "Notified Consignee"),
            ("ready for collection", "RFD", "Ready for Collection"),
            ("shipment ready for delivery", "RFD", "Shipment Ready For Delivery"),
            ("shipment received from flight", "RCF", "Shipment Received From Flight"),
            ("received at destination", "RCF", "Received At Destination"),
            ("received in", "RCF", "Received"),
            ("cargo received", "RCF", "Cargo Received"),
            ("delivered to the consignee", "DLV", "Delivered to the Consignee"),
            ("shipment delivered", "DLV", "Shipment Delivered"),
            ("delivered", "DLV", "Delivered"),
            ("document released", "DOC", "Document Released"),
            ("customs released", "REL", "Customs Released"),
            ("released", "REL", "Released"),
            ("flight arrival", "ARR", "Flight Arrival"),
            ("arrived", "ARR", "Arrived"),
            ("departed", "DEP", "Departed"),
            ("accepted", "RCS", "Accepted"),
            ("manifested", "MAN", "Manifested"),
            ("booked", "BKD", "Booked"),
            ("in transit", "TRN", "In Transit")
        ]

        var chronological: [TrackingEvent] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = collapseWhitespace(raw)
            guard !line.isEmpty, line.count <= 260 else { continue }
            let lower = line.lowercased()
            guard let matched = known.first(where: { lower.contains($0.needle) }) else { continue }

            let timestamp = firstTimestamp(in: line)
            let location = regexGroups(#"\bStation\s+([A-Z]{3})\b"#, in: line, caseInsensitive: true)?.first?.uppercased()
                ?? regexGroups(#"\b(?:at|to|from|in|-)\s*([A-Z]{3})\b"#, in: line, caseInsensitive: true)?.first?.uppercased()
            let flight = regexAllMatches(#"\b[A-Z]{2}[- ]?\d{2,4}\b"#, in: line, caseInsensitive: true).last?
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
            chronological.append(TrackingEvent(code: matched.code, title: matched.title, location: location, timestamp: timestamp, flightNumber: flight))
        }
        return normalizedRecentEvents(Array(chronological.reversed()))
    }

    private static func firstTimestamp(in text: String) -> String? {
        let patterns = [
            #"\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4},?\s+\d{2}:\d{2}(?::\d{2})?\b"#,
            #"\b\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}(?::\d{2})?\b"#,
            #"\b\d{1,2}\.\d{1,2}\.\d{4}\s+\d{2}:\d{2}(?::\d{2})?\b"#,
            #"\b\d{1,2}/\d{1,2}/\d{4}\s+\d{2}:\d{2}(?::\d{2})?\b"#,
            #"\b\d{1,2}\s+[A-Z]+\s+\d{4},?\s+\d{2}:\d{2}(?::\d{2})?\b"#,
            #"\b\d{1,2}\s+[A-Za-z]{3}\s+\d{4},?\s+\d{2}:\d{2}(?::\d{2})?\b"#
        ]
        for pattern in patterns {
            if let match = regexAllMatches(pattern, in: text, caseInsensitive: true).last {
                return match
            }
        }
        return nil
    }

    private static func qatarCargoSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        guard lower.contains("notified consignee") || lower.contains("received at destination") ||
                lower.contains("received in") || lower.contains("arrived in") || lower.contains("departed from") ||
                lower.contains("delivered") else {
            return nil
        }

        let route = regexGroups(
            #"\(\s*([A-Z]{3})\s*-\s*([A-Z]{3})\s*\)"#,
            in: collapsed,
            caseInsensitive: true
        )
        let origin = (route?.count ?? 0) >= 2 ? route?[0].uppercased() : nil
        let destination = (route?.count ?? 0) >= 2 ? route?[1].uppercased() : nil

        let pieceWeight = regexGroups(
            #"\b(\d{1,5})\s*(?:Piece\(s\)|Pcs)\s*\|?\s*([\d,.]+)\s*Kg\b"#,
            in: collapsed,
            caseInsensitive: true
        )
        let pieces = pieceWeight?.first.flatMap(Int.init)
        let weight = (pieceWeight?.count ?? 0) >= 2
            ? Decimal(string: pieceWeight?[1].replacingOccurrences(of: ",", with: "") ?? "")
            : nil

        let recentEvents = qatarRecentEvents(from: text, destination: destination)
        let latest = recentEvents?.first
        let destinationArrival = recentEvents?.first(where: { event in
            let title = event.title.lowercased()
            guard title.contains("arrived in") else { return false }
            guard let destination else { return true }
            return event.location?.caseInsensitiveCompare(destination) == .orderedSame || title.contains(destination.lowercased())
        })
        let departureEvent = recentEvents?.first(where: { $0.title.lowercased().contains("departed from") })

        let flight = destinationArrival.flatMap { event in
            regexGroups(#"\bQR\s*[- ]?(\d{3,4})\b"#, in: event.title, caseInsensitive: true)?.first.map { "QR\($0)" }
        } ?? regexAllMatches(#"\bQR\s*[- ]?\d{3,4}\b"#, in: collapsed, caseInsensitive: true).last?
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        let status: String? = {
            if let latest { return latest.title }
            if lower.contains("received at destination") { return "Received at Destination" }
            if lower.contains("notified consignee") { return "Notified consignee" }
            return nil
        }()
        let lastEvent: String? = latest.map { event in
            [event.title, event.timestamp].compactMap { $0 }.joined(separator: " — ")
        }

        let meaningful: [Any?] = [origin, destination, pieces, weight, flight, status, latest]
        guard meaningful.contains(where: { $0 != nil }) else { return nil }

        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: cleanedTechnicalValue(flight),
            origin: origin,
            destination: destination,
            departure: departureEvent?.timestamp,
            arrival: destinationArrival?.timestamp,
            pieces: pieces,
            weightKg: weight,
            status: cleanedDisplayValue(status),
            lastEvent: cleanedDisplayValue(lastEvent),
            recentEvents: recentEvents,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func qatarRecentEvents(from text: String, destination: String?) -> [TrackingEvent]? {
        let lines = text.components(separatedBy: .newlines)
            .map(collapseWhitespace)
            .filter { !$0.isEmpty && !$0.hasPrefix("__CT_") }

        var events: [TrackingEvent] = []
        for index in lines.indices {
            let line = lines[index]
            let lower = line.lowercased()
            let isNotified = lower == "notified consignee" || lower.hasPrefix("notified consignee ")
            let isReceived = lower.hasPrefix("received in ")
            let isArrived = lower.hasPrefix("arrived in ")
            let isDeparted = lower.hasPrefix("departed from ")
            let isDelivered = lower == "delivered" || lower.hasPrefix("delivered ") || lower.hasPrefix("shipment delivered")
            guard isNotified || isReceived || isArrived || isDeparted || isDelivered else { continue }

            // Qatar's real timeline cards always put the shipment piece/weight row immediately under
            // the event title, then the event timestamp. This avoids promoting the larger summary
            // heading (which can repeat "Notified consignee") as a duplicate fake event.
            let nextIndex = lines.index(after: index)
            guard nextIndex < lines.endIndex else { continue }
            let detailLine = lines[nextIndex].lowercased()
            guard detailLine.contains("pcs") || detailLine.contains("piece(s)") else { continue }

            let searchEnd = min(lines.count, index + 4)
            let nearby = lines[(index + 1)..<searchEnd].joined(separator: " ")
            guard let timestamp = firstTimestamp(in: nearby) else { continue }

            let location: String? = {
                if isNotified || isDelivered { return destination }
                if let code = regexGroups(#"\b(?:in|from|at)\s+([A-Z]{3})\b"#, in: line, caseInsensitive: true)?.first {
                    return code.uppercased()
                }
                return nil
            }()

            let code: String? = {
                if isDelivered { return "DLV" }
                if isNotified { return "NFD" }
                if isReceived { return "RCF" }
                if isArrived { return "ARR" }
                if isDeparted { return "DEP" }
                return nil
            }()
            let flight = regexAllMatches(#"\bQR\s*[- ]?\d{3,4}\b"#, in: line, caseInsensitive: true).last?
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .uppercased()

            events.append(TrackingEvent(
                code: code,
                title: line,
                location: location,
                timestamp: timestamp,
                flightNumber: flight
            ))
        }
        return normalizedRecentEvents(events)
    }

    private static func turkishCargoSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        guard lower.contains("piece(s)") || lower.contains("cargo reservation information") else { return nil }

        let route = regexGroups(
            #"\bFrom\s+([A-Z]{3})\b.*?\bTo\s+([A-Z]{3})\b"#,
            in: collapsed,
            caseInsensitive: true
        )
        let origin = (route?.count ?? 0) >= 2 ? route?[0].uppercased() : nil
        let destination = (route?.count ?? 0) >= 2 ? route?[1].uppercased() : nil
        let pieces = regexGroups(#"\b(\d{1,5})\s+piece\(s\)"#, in: collapsed, caseInsensitive: true)?.first.flatMap(Int.init)
        let weight = regexGroups(#"\b\d{1,5}\s+piece\(s\)\s+([\d,.]+)\s*kg\b"#, in: collapsed, caseInsensitive: true)?.first
            .flatMap { Decimal(string: $0.replacingOccurrences(of: ",", with: "")) }
            ?? regexGroups(#"\b([\d,.]+)\s*kg\b"#, in: collapsed, caseInsensitive: true)?.first
                .flatMap { Decimal(string: $0.replacingOccurrences(of: ",", with: "")) }

        let flight = regexAllMatches(#"\bTK\d{3,4}\b"#, in: collapsed, caseInsensitive: true).last?.uppercased()

        // Turkish Cargo renders a high-level shipment summary (for example "In Transit - MCT")
        // AND a chronological event-card timeline. Keep the three newest real event cards and use
        // those operational milestones as the authoritative status source.
        let turkishEvents = turkishEventCards(in: collapsed)
        let recentEvents = normalizedRecentEvents(Array(turkishEvents.reversed()))
        let deliveredEvent = turkishEvents.last(where: { event in
            event.code == "DLV" || event.title.lowercased().contains("delivered")
        })
        let nfdEvent = turkishEvents.last(where: { event in
            event.code == "NFD" || event.title.caseInsensitiveCompare("Shipment Notified For Delivery") == .orderedSame
        })
        let destinationRCF = turkishEvents.last(where: { event in
            let isRCF = event.code == "RCF" || event.title.caseInsensitiveCompare("Shipment Received From Flight") == .orderedSame
            let atDestination = destination == nil || event.location == destination
            return isRCF && atDestination
        })

        var status: String?
        var lastEvent: String?

        if let deliveredEvent {
            status = "Delivered"
            if let timestamp = deliveredEvent.timestamp {
                lastEvent = "DLV - Delivered — \(timestamp)"
            } else {
                lastEvent = "DLV - Delivered"
            }
        } else if let nfdEvent {
            status = "Ready for Delivery"
            if let timestamp = nfdEvent.timestamp {
                lastEvent = "NFD - Shipment Notified For Delivery — \(timestamp)"
            } else {
                lastEvent = "NFD - Shipment Notified For Delivery"
            }
        } else if let destinationRCF {
            if let destination {
                status = "Arrived - \(destination)"
            } else {
                status = "Arrived"
            }
            if let timestamp = destinationRCF.timestamp {
                lastEvent = "RCF - Shipment Received From Flight — \(timestamp)"
            } else {
                lastEvent = "RCF - Shipment Received From Flight"
            }
        } else {
            // Fall back to Turkish Cargo's general summary only when no more-specific event card exists.
            for pattern in [
                #"\bDelivered(?:\s+to\s+the\s+Consignee)?\b"#,
                #"\bReady\s+for\s+Delivery\b"#,
                #"\bArrived(?:\s*-\s*[A-Z]{3})?\b"#,
                #"\bReceived(?:\s*-\s*[A-Z]{3})?\b"#,
                #"\bAccepted(?:\s*-\s*[A-Z]{3})?\b"#,
                #"\bIn\s+Transit\s*-\s*[A-Z]{3}\b"#
            ] {
                if let match = regexAllMatches(pattern, in: collapsed, caseInsensitive: true).first {
                    status = cleanedDisplayValue(match)
                    break
                }
            }
            lastEvent = status
            if let status,
               let timestamp = regexGroups(
                NSRegularExpression.escapedPattern(for: status) + #"\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{2}:\d{2})"#,
                in: collapsed,
                caseInsensitive: true
               )?.first {
                lastEvent = "\(status) — \(timestamp)"
            }
        }
        guard origin != nil || destination != nil || pieces != nil || weight != nil || status != nil else { return nil }
        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: flight,
            origin: origin,
            destination: destination,
            departure: nil,
            arrival: nil,
            pieces: pieces,
            weightKg: weight,
            status: status,
            lastEvent: lastEvent,
            recentEvents: recentEvents ?? genericRecentAirlineEvents(from: text),
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func turkishEventCards(in text: String) -> [TrackingEvent] {
        let cards = regexAllMatches(
            #"\bStation\s+[A-Z]{3}\b.*?(?=\bStation\s+[A-Z]{3}\b|$)"#,
            in: text,
            caseInsensitive: true
        )
        return cards.compactMap { card in
            let station = regexGroups(#"\bStation\s+([A-Z]{3})\b"#, in: card, caseInsensitive: true)?.first?.uppercased()
            let code = regexAllMatches(#"\b(?:RCS|DEP|RCF|NFD|DLV|BKD|MAN|PRE)\b"#, in: card, caseInsensitive: true).last?.uppercased()
            let description = regexGroups(
                #"\bDescription\s+(.+?)(?=\s+(?:Planned\s+pieces/weight|Actual\s+pieces|Actual\s+time|ETA\b|ETD\b|Station\b)|$)"#,
                in: card,
                caseInsensitive: true
            )?.first.flatMap { cleanedDisplayValue($0) }
            guard let title = description else { return nil }
            let rawTimestamp = regexGroups(
                #"\bActual\s+time\s+(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#,
                in: card,
                caseInsensitive: true
            )?.first
            let eventFlight = regexGroups(#"\bFlight\s+no\s+([A-Z0-9-]{3,10})\b"#, in: card, caseInsensitive: true)?.first?
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
            return TrackingEvent(
                code: code,
                title: title,
                location: station,
                timestamp: rawTimestamp.map(turkishDisplayTimestamp),
                flightNumber: eventFlight
            )
        }
    }

    private static func turkishEventCard(
        description: String,
        in text: String
    ) -> TrackingEvent? {
        turkishEventCards(in: text).last(where: { $0.title.caseInsensitiveCompare(description) == .orderedSame })
    }

    private static func turkishDeliveredEventCard(in text: String) -> TrackingEvent? {
        turkishEventCards(in: text).last(where: { event in
            event.code == "DLV" || event.title.lowercased().contains("delivered")
        })
    }

    private static func turkishDisplayTimestamp(_ raw: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "dd.MM.yyyy HH:mm"
        guard let date = input.date(from: raw) else { return raw }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "dd MMM yyyy HH:mm"
        return output.string(from: date)
    }

    private static func emiratesSkyCargoSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        guard lower.contains("doc. no") || lower.contains("doc no") else { return nil }
        guard lower.contains("gross weight") || lower.contains("search results") else { return nil }

        let route = regexGroups(
            #"\b([A-Z][A-Z .'-]{1,48})\s*\(([A-Z]{3})\)\s*[-–—.>\s]+\s*([A-Z][A-Z .'-]{1,48})\s*\(([A-Z]{3})\)"#,
            in: collapsed,
            caseInsensitive: true
        )
        let origin = (route?.count ?? 0) >= 4 ? route?[1].uppercased() : nil
        let destination = (route?.count ?? 0) >= 4 ? route?[3].uppercased() : nil

        let pieces = regexGroups(#"\bPieces\s+(\d{1,5})\b"#, in: collapsed, caseInsensitive: true)?
            .first.flatMap(Int.init)
        let weight = regexGroups(
            #"\bGross\s+Weight\s+([\d,.]+)\s*(?:K|KG|KGS)\b"#,
            in: collapsed,
            caseInsensitive: true
        )?.first.flatMap { Decimal(string: $0.replacingOccurrences(of: ",", with: "")) }

        var status: String?
        if let captured = regexGroups(
            #"Search\s+Results\s*\(\d+\)\s+(.+?)\s+Doc\.?\s*No\.?\s*[:：]?"#,
            in: collapsed,
            caseInsensitive: true
        )?.first {
            status = cleanedDisplayValue(captured)
        }
        if status == nil {
            let knownStatuses = [
                "Delivered to the Consignee", "Ready for Delivery", "Arrived", "Departed",
                "In Transit", "Accepted", "Booked", "Received"
            ]
            status = knownStatuses.first(where: { lower.contains($0.lowercased()) })
        }

        guard origin != nil || destination != nil || pieces != nil || weight != nil || status != nil else {
            return nil
        }

        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: nil,
            origin: origin,
            destination: destination,
            departure: nil,
            arrival: nil,
            pieces: pieces,
            weightKg: weight,
            status: status,
            lastEvent: status,
            recentEvents: genericRecentAirlineEvents(from: text),
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func smartKargoSnapshot(
        from text: String,
        airlineName: String,
        airlinePrefix: String,
        sourceURL: URL
    ) -> AirlineTrackingSnapshot? {
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        guard lower.contains("status history") || lower.contains("booking and acceptance information") || lower.contains("last activity") else {
            return nil
        }

        let routeMatch = regexGroups(#"\(([A-Z]{3})\s*[-–]\s*([A-Z]{3})\)"#, in: collapsed, caseInsensitive: false)
        let origin = routeMatch?.count == 2 ? routeMatch?[0] : nil
        let destination = routeMatch?.count == 2 ? routeMatch?[1] : nil

        let pieceWeight = regexGroups(#"\b(\d{1,5})\s*P\s*/\s*([\d,.]+)\s*Kgs?\b"#, in: collapsed, caseInsensitive: true)
        let pieces = pieceWeight.flatMap { $0.first }.flatMap(Int.init)
        let weight = pieceWeight.flatMap { $0.count > 1 ? Decimal(string: $0[1].replacingOccurrences(of: ",", with: "")) : nil }

        let arrivedRow = regexGroups(
            #"\b([A-Z]{3})\s+Arrived\s+(\d{1,5})\s+([\d,.]+)\s+Kgs?\s+([A-Z0-9]{2,8})\s+(\d{2}/\d{2}/\d{4})\s+(?:ETA:\s*)?(\d{2}:\d{2})"#,
            in: collapsed,
            caseInsensitive: true
        )
        let departedRow = regexGroups(
            #"\b([A-Z]{3})\s+Departed\s+(\d{1,5})\s+([\d,.]+)\s+Kgs?\s+([A-Z0-9]{2,8})\s+(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})"#,
            in: collapsed,
            caseInsensitive: true
        )

        let flight = arrivedRow?.count ?? 0 >= 4 ? arrivedRow?[3] : (departedRow?.count ?? 0 >= 4 ? departedRow?[3] : nil)
        let departure = (departedRow?.count ?? 0 >= 6) ? "\(departedRow![4]) \(departedRow![5])" : nil
        let arrival = (arrivedRow?.count ?? 0 >= 6) ? "\(arrivedRow![4]) \(arrivedRow![5])" : nil

        let smartKargoCoreEvents = smartKargoRecentEvents(from: text) ?? []
        let smartKargoAdditionalEvents = (genericRecentAirlineEvents(from: text) ?? []).filter { event in
            ["DLV", "NFD", "RFD", "DOC", "REL"].contains(event.code?.uppercased() ?? "")
        }
        let smartKargoEvents = normalizedRecentEvents(smartKargoCoreEvents + smartKargoAdditionalEvents)

        var status: String?
        var lastEvent: String?
        if let latest = smartKargoEvents?.first {
            switch latest.code?.uppercased() {
            case "DLV": status = "Delivered"
            case "NFD", "RFD": status = "Ready for Delivery"
            case "ARR": status = latest.location.map { "Arrived at \($0)" } ?? "Arrived"
            case "DEP": status = latest.location.map { "Departed from \($0)" } ?? "Departed"
            case "RCS": status = "Accepted"
            case "BKD": status = "Booked"
            default: status = latest.title
            }
            lastEvent = [latest.code, latest.title, latest.location, latest.timestamp].compactMap { $0 }.joined(separator: " — ")
        } else if let destination, lower.contains("arrived at \(destination.lowercased())") {
            status = "Arrived at \(destination)"
            lastEvent = status
        } else if lower.contains("arrived") {
            status = "Arrived"
            lastEvent = "Arrived"
        } else if lower.contains("departed") {
            status = "Departed"
            lastEvent = "Departed"
        } else if lower.contains("accepted") {
            status = "Accepted"
            lastEvent = "Accepted"
        }

        guard flight != nil || origin != nil || destination != nil || pieces != nil || weight != nil || status != nil else {
            return nil
        }

        return AirlineTrackingSnapshot(
            sourceState: .live,
            airlineName: airlineName,
            airlinePrefix: airlinePrefix,
            flightNumber: flight?.uppercased(),
            origin: origin?.uppercased(),
            destination: destination?.uppercased(),
            departure: departure,
            arrival: arrival,
            pieces: pieces,
            weightKg: weight,
            status: status,
            lastEvent: lastEvent,
            recentEvents: smartKargoEvents,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private static func smartKargoRecentEvents(from text: String) -> [TrackingEvent]? {
        var chronological: [TrackingEvent] = []

        let movementPattern = #"\b([A-Z]{3})\s+(Departed|Arrived)\s+\d{1,5}\s+[\d,.]+\s+Kgs?\s+([A-Z0-9]{2,8})\s+(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})"#
        for groups in regexAllGroups(movementPattern, in: text, caseInsensitive: true) where groups.count >= 5 {
            let station = groups[0].uppercased()
            let movement = groups[1].capitalized
            let code = movement.lowercased() == "arrived" ? "ARR" : "DEP"
            chronological.append(TrackingEvent(code: code, title: movement, location: station, timestamp: "\(groups[3]) \(groups[4])"))
        }

        let acceptedPattern = #"\bAccepted\s+([A-Z]{3})\s+[A-Z]{3}\s+\d{1,5}\s+[\d,.]+\s+Kgs?\s+(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})"#
        for groups in regexAllGroups(acceptedPattern, in: text, caseInsensitive: true) where groups.count >= 3 {
            chronological.append(TrackingEvent(code: "RCS", title: "Accepted", location: groups[0].uppercased(), timestamp: "\(groups[1]) \(groups[2])"))
        }

        let bookedPattern = #"\bBooked(?:\s+\[[A-Z]\])?\s+([A-Z]{3})\s+[A-Z]{3}\s+\d{1,5}\s+[\d,.]+\s+Kgs?.*?(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})"#
        for groups in regexAllGroups(bookedPattern, in: text, caseInsensitive: true) where groups.count >= 3 {
            chronological.append(TrackingEvent(code: "BKD", title: "Booked", location: groups[0].uppercased(), timestamp: "\(groups[1]) \(groups[2])"))
        }

        // SmartKargo repeats milestones in multiple sections. De-duplicate them, then sort using
        // the actual source timestamp rather than a fixed ARR > DEP > RCS > BKD priority.
        return normalizedRecentEvents(chronological)
    }

    public static func transomSnapshot(from text: String, sourceURL: URL) -> TransomTrackingSnapshot? {
        let rows = transomTableRows(from: text)
        let eventRows = transomEventRows(from: rows)
        let recentEvents = normalizedRecentEvents(Array(eventRows.reversed()).map(transomTrackingEvent(from:)))

        var expected = firstInteger(
            in: text,
            labelPatterns: ["manifested pcs", "manifested pieces", "expected pieces", "total pieces", "pieces"]
        )
        if expected == nil,
           let headerIndex = rows.firstIndex(where: { row in
               row.contains(where: { $0.caseInsensitiveCompare("Total Pieces") == .orderedSame || $0.caseInsensitiveCompare("Total Piece") == .orderedSame })
           }), headerIndex + 1 < rows.count {
            let header = rows[headerIndex]
            let data = rows[headerIndex + 1]
            if let idx = header.firstIndex(where: { $0.lowercased().hasPrefix("total piec") }), idx < data.count {
                expected = integer(from: data[idx])
            }
        }

        var received = firstInteger(
            in: text,
            labelPatterns: ["received pcs", "received pieces", "rcvd pcs", "rcf pcs", "pieces received"]
        )
        if received == nil { received = transomValue(afterLabel: "Received Pieces", in: rows).flatMap(integer(from:)) }
        if received == nil {
            received = eventRows.compactMap { piecesFromTransomEventStatus($0.statusText) }.max()
        }
        if expected == nil, let eventPieces = eventRows.compactMap({ piecesFromTransomEventStatus($0.statusText) }).max() {
            expected = eventPieces
        }

        let explicitShort = firstInteger(
            in: text,
            labelPatterns: ["short landed", "short land", "shortland", "short pieces"]
        )
        var weight = firstDecimal(
            in: text,
            labelPatterns: ["received weight", "rcvd wt", "gross weight", "weight"]
        )
        if weight == nil { weight = transomValue(afterLabel: "Received Weight", in: rows).flatMap(decimal(from:)) }

        let origin = airportCode(from: transomValue(afterLabel: "Origin", in: rows) ?? firstValue(in: text, labels: ["origin"]))
        let destination = airportCode(from: transomValue(afterLabel: "Destination", in: rows) ?? firstValue(in: text, labels: ["destination"]))
        let importExport = cleanedDisplayValue(transomValue(afterLabel: "Import/Export", in: rows) ?? firstValue(in: text, labels: ["import/export"]))
        let agent = cleanedDisplayValue(transomValue(afterLabel: "Agent", in: rows) ?? firstValue(in: text, labels: ["agent"]))

        var flightNumber: String?
        var flightDate: String?
        if let headerIndex = rows.firstIndex(where: { row in
            row.contains(where: { $0.caseInsensitiveCompare("Flight No") == .orderedSame || $0.caseInsensitiveCompare("Flight Number") == .orderedSame })
        }), headerIndex + 1 < rows.count {
            let header = rows[headerIndex]
            let data = rows[headerIndex + 1]
            if let idx = header.firstIndex(where: { $0.lowercased().hasPrefix("flight no") }), idx < data.count {
                flightNumber = cleanedTechnicalValue(data[idx])?.uppercased()
            }
            if let idx = header.firstIndex(where: { $0.caseInsensitiveCompare("Flight Date") == .orderedSame }), idx < data.count {
                flightDate = cleanedDisplayValue(data[idx])
            }
        }
        if flightNumber == nil {
            flightNumber = cleanedTechnicalValue(firstValue(in: text, labels: ["flight no", "flight number"]))?.uppercased()
        }
        if flightDate == nil {
            flightDate = cleanedDisplayValue(firstValue(in: text, labels: ["flight date"]))
        }

        // Prefer the explicit Events Status table. Generic key/value API payloads can contain
        // unrelated values such as "Pending" or "Irregularity", so those are only fallbacks.
        let collapsed = collapseWhitespace(text)
        let lower = collapsed.lowercased()
        let latestEventRow = eventRows.last
        var status = cleanedDisplayValue(latestEventRow?.eventName) ??
            cleanedDisplayValue(firstValue(in: text, labels: ["shipment status", "current status"]))
        var lastEvent = latestEventRow.flatMap(transomLastEventText(from:)) ??
            cleanedDisplayValue(firstValue(in: text, labels: ["last event", "latest event", "latest status", "milestone"]))

        if latestEventRow == nil, lower.contains("document released") {
            status = "Document Released"
            if let event = regexGroups(#"Air Waybill Document delivered\s+([0-9]{1,2}\s+[A-Z]+\s+[0-9]{4}\s+[0-9]{2}:[0-9]{2})"#, in: collapsed, caseInsensitive: true)?.first {
                lastEvent = "Document Released — \(event)"
            } else {
                lastEvent = "Document Released"
            }
        } else if latestEventRow == nil, lower.contains("shipment ready for delivery") {
            status = "Shipment ready for delivery"
            if let event = regexGroups(#"Shipment ready for delivery\s+([0-9]{1,2}\s+[A-Z]+\s+[0-9]{4}\s+[0-9]{2}:[0-9]{2})"#, in: collapsed, caseInsensitive: true)?.first {
                lastEvent = "Shipment ready for delivery — \(event)"
            } else {
                lastEvent = "Shipment ready for delivery"
            }
        } else if latestEventRow == nil, lower.contains("flight arrival") {
            status = "Flight Arrival"
            if let event = regexGroups(#"Flight Arrival\s+([0-9]{1,2}\s+[A-Z]+\s+[0-9]{4}\s+[0-9]{2}:[0-9]{2})"#, in: collapsed, caseInsensitive: true)?.first {
                lastEvent = "Flight Arrival — \(event)"
            } else {
                lastEvent = "Flight Arrival"
            }
        }

        let shortLanded: Int?
        if let explicitShort, explicitShort > 0 {
            shortLanded = explicitShort
        } else if let expected, let received, expected >= received {
            let difference = expected - received
            shortLanded = difference > 0 ? difference : nil
        } else {
            shortLanded = nil
        }

        let state = arrivalState(
            status: status,
            lastEvent: lastEvent,
            expectedPieces: expected,
            receivedPieces: received,
            shortLandedPieces: shortLanded,
            pageText: text
        )

        guard expected != nil || received != nil || weight != nil || origin != nil || destination != nil ||
              flightNumber != nil || agent != nil || status != nil || lastEvent != nil || state != .unknown else {
            return nil
        }

        return TransomTrackingSnapshot(
            sourceState: .live,
            arrivalState: state,
            receivedPieces: received,
            expectedPieces: expected,
            shortLandedPieces: shortLanded,
            weightKg: weight,
            origin: origin,
            destination: destination,
            flightNumber: flightNumber,
            flightDate: flightDate,
            importExport: importExport,
            agent: agent,
            status: status,
            lastEvent: lastEvent,
            recentEvents: recentEvents,
            sourceURL: sourceURL,
            fetchedAt: Date()
        )
    }

    private struct TransomEventRow {
        let statusText: String
        let eventName: String
    }

    private static func transomEventRows(from rows: [[String]]) -> [TransomEventRow] {
        guard let headerIndex = rows.firstIndex(where: { row in
            let normalized = row.map { $0.lowercased() }
            return normalized.contains("status") && normalized.contains("event name")
        }) else { return [] }

        let header = rows[headerIndex].map { $0.lowercased() }
        guard let statusIndex = header.firstIndex(of: "status"),
              let eventIndex = header.firstIndex(of: "event name") else { return [] }

        var events: [TransomEventRow] = []
        for row in rows.dropFirst(headerIndex + 1) {
            if row.map({ $0.lowercased() }).contains("status") &&
               row.map({ $0.lowercased() }).contains("event name") { continue }
            guard statusIndex < row.count, eventIndex < row.count else {
                if !events.isEmpty { break }
                continue
            }
            let statusText = row[statusIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let eventName = row[eventIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !statusText.isEmpty, !eventName.isEmpty else {
                if !events.isEmpty { break }
                continue
            }
            let eventLower = eventName.lowercased()
            let looksOperational = eventLower.contains("arrival") || eventLower.contains("delivery") ||
                eventLower.contains("released") || eventLower.contains("received") ||
                eventLower.contains("depart") || eventLower.contains("flight") ||
                eventLower.contains("document") || eventLower.contains("shipment")
            if !looksOperational {
                if !events.isEmpty { break }
                continue
            }
            events.append(TransomEventRow(statusText: statusText, eventName: eventName))
        }
        return events
    }

    private static func piecesFromTransomEventStatus(_ value: String) -> Int? {
        regexGroups(#"\b(\d{1,6})\s*PCS\b"#, in: value, caseInsensitive: true)?.first.flatMap(Int.init)
    }

    private static func transomTrackingEvent(from event: TransomEventRow) -> TrackingEvent {
        let lower = event.eventName.lowercased()
        let code: String?
        if lower.contains("document released") { code = "DOC" }
        else if lower.contains("ready for delivery") { code = "RFD" }
        else if lower.contains("arrival") { code = "ARR" }
        else if lower.contains("depart") { code = "DEP" }
        else if lower.contains("received") { code = "RCF" }
        else { code = nil }
        let timestamp = regexGroups(#"\b([0-9]{1,2}\s+[A-Z]+\s+[0-9]{4}\s+[0-9]{2}:[0-9]{2})\b"#, in: event.statusText, caseInsensitive: true)?.first
        let flight = regexAllMatches(#"\b[A-Z]{2}\s?\d{3,4}\b"#, in: event.statusText, caseInsensitive: true).last?
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        return TrackingEvent(code: code, title: event.eventName, location: nil, timestamp: timestamp, flightNumber: flight)
    }

    private static func transomLastEventText(from event: TransomEventRow) -> String? {
        let name = cleanedDisplayValue(event.eventName)
        guard let name else { return nil }
        if let timestamp = regexGroups(#"\b([0-9]{1,2}\s+[A-Z]+\s+[0-9]{4}\s+[0-9]{2}:[0-9]{2})\b"#, in: event.statusText, caseInsensitive: true)?.first {
            return "\(name) — \(timestamp)"
        }
        return name
    }

    private static func transomTableRows(from text: String) -> [[String]] {
        guard let markerRange = text.range(of: "__CT_TABLE_ROWS__") else { return [] }
        let suffix = text[markerRange.upperBound...]
        return suffix
            .components(separatedBy: .newlines)
            .map { line in
                line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .filter { row in row.contains(where: { !$0.isEmpty }) }
    }

    private static func transomValue(afterLabel label: String, in rows: [[String]]) -> String? {
        let target = label.lowercased()
        for row in rows {
            for index in row.indices where row[index].lowercased() == target {
                if index + 1 < row.count {
                    let value = row[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }

    private static func arrivalState(
        status: String?,
        lastEvent: String?,
        expectedPieces: Int?,
        receivedPieces: Int?,
        shortLandedPieces: Int?,
        pageText: String
    ) -> CargoArrivalState {
        if let shortLandedPieces, shortLandedPieces > 0 { return .partial }
        if let expectedPieces, let receivedPieces, expectedPieces > 0, receivedPieces == expectedPieces { return .arrived }

        let evidence = ([status, lastEvent].compactMap { $0 }.joined(separator: " ") + " " + pageText).lowercased()
        if evidence.contains("not arrived") || evidence.contains("not received") { return .notArrived }
        if evidence.contains("received from flight") || evidence.contains("cargo received") || evidence.contains("arrived") || tokenExists("RCF", in: pageText) {
            return .arrived
        }
        if evidence.contains("departed") || evidence.contains("in transit") || evidence.contains("in-transit") {
            return .inTransit
        }
        return .unknown
    }

    private static func firstValue(in text: String, labels: [String]) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for index in lines.indices {
            let line = lines[index]
            let lowerLine = line.lowercased()
            for label in labels {
                let lowerLabel = label.lowercased()
                guard let range = lowerLine.range(of: lowerLabel) else { continue }

                let suffix = String(line[range.upperBound...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :|-–—\t"))
                if !suffix.isEmpty, !looksLikeAnotherLabel(suffix) {
                    return suffix
                }

                if index + 1 < lines.count {
                    let next = lines[index + 1]
                    if !next.isEmpty, !looksLikeAnotherLabel(next) {
                        return next
                    }
                }
            }
        }
        return nil
    }

    private static func firstInteger(in text: String, labelPatterns: [String]) -> Int? {
        for label in labelPatterns {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            if let groups = regexGroups("(?i)\\b\(escaped)\\b\\s*[:|=-]?\\s*(\\d{1,6})", in: collapseWhitespace(text), caseInsensitive: true),
               let first = groups.first,
               let value = Int(first) {
                return value
            }
        }
        return integer(from: firstValue(in: text, labels: labelPatterns))
    }

    private static func firstDecimal(in text: String, labelPatterns: [String]) -> Decimal? {
        for label in labelPatterns {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            if let groups = regexGroups("(?i)\\b\(escaped)\\b\\s*[:|=-]?\\s*([\\d,.]+)", in: collapseWhitespace(text), caseInsensitive: true),
               let first = groups.first {
                return Decimal(string: first.replacingOccurrences(of: ",", with: ""))
            }
        }
        return decimal(from: firstValue(in: text, labels: labelPatterns))
    }

    private static func looksLikeAnotherLabel(_ value: String) -> Bool {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let knownLabels = [
            "flight", "route", "origin", "destination", "departure", "arrival", "pieces", "pcs",
            "weight", "status", "last event", "received pieces", "manifested pcs", "awb", "hawb"
        ]
        return knownLabels.contains(normalized)
    }

    private static func integer(from value: String?) -> Int? {
        guard let value else { return nil }
        let pattern = #"\b(\d{1,6})\b"#
        guard let match = regexGroups(pattern, in: value, caseInsensitive: false)?.first else { return nil }
        return Int(match)
    }

    private static func decimal(from value: String?) -> Decimal? {
        guard let value else { return nil }
        let normalized = value.replacingOccurrences(of: ",", with: "")
        let pattern = #"\b(\d+(?:\.\d+)?)\b"#
        guard let match = regexGroups(pattern, in: normalized, caseInsensitive: false)?.first else { return nil }
        return Decimal(string: match)
    }

    private static func airportCode(from value: String?) -> String? {
        guard let value else { return nil }
        let upper = value.uppercased()
        let pattern = #"\b([A-Z]{3})\b"#
        return regexGroups(pattern, in: upper, caseInsensitive: false)?.first
    }

    private static func cleanedTechnicalValue(_ value: String?) -> String? {
        cleanedDisplayValue(value)?.uppercased()
    }

    private static func cleanedDisplayValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func collapseWhitespace(_ value: String) -> String {
        value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func regexAllMatches(_ pattern: String, in text: String, caseInsensitive: Bool) -> [String] {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func regexAllGroups(_ pattern: String, in text: String, caseInsensitive: Bool) -> [[String]] {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                guard let r = Range(match.range(at: index), in: text) else { return nil }
                return String(text[r])
            }
        }
    }

    private static func regexGroups(_ pattern: String, in text: String, caseInsensitive: Bool) -> [String]? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let r = Range(match.range(at: index), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static func tokenExists(_ token: String, in text: String) -> Bool {
        let pattern = #"\b\#(token)\b"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
