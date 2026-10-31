// Ports of the iOS business-rule services:
// DutyCalculatorService, DifferenceCalculatorService, CurrencyConversionService, UnitConversionService.
import { Dec, D } from "./decimal.js";

export const CONFIG = {
  vatRate: D("0.05"),
  dutyAndVatAdjustment: D("97.566"),
  vatOnlyAdjustment: D("200.000"),
  insuranceRate: D("0.01"),
  quickEstimateDutyRate: D("0.05"),
  documentationGuaranteeRate: D("0.02"),
  documentationGuaranteeThresholdOMR: D("1000"),
  omanDutyCalculatorURL: "https://www.customs.gov.om/esw/jsf/secure/esw/common/DutyCalculator.xhtml",
  omanHSRequirementsURL: "https://www.customs.gov.om/esw/jsf/secure/esw/common/PublicHSCodeSearch.xhtml",
  trustedGoldPriceURL: "https://www.gold-price-today.com/oman/",
};

export const CURRENCIES = [
  { code: "OMR", en: "Omani Rial", ar: "ريال عُماني", digits: 3, suggested: "1" },
  { code: "USD", en: "US Dollar", ar: "دولار أمريكي", digits: 2, suggested: "0.385" },
  { code: "AED", en: "UAE Dirham", ar: "درهم إماراتي", digits: 2, suggested: "0.1048" },
  { code: "EUR", en: "Euro", ar: "يورو", digits: 2, suggested: "" },
  { code: "GBP", en: "British Pound", ar: "جنيه إسترليني", digits: 2, suggested: "" },
];
export const currency = (code) => CURRENCIES.find((c) => c.code === code) ?? CURRENCIES[0];

// ---------------- Duty calculator ----------------

export const BAYAN_FEE = { company: D("15"), personal: D("5") };

export function parsePercentage(text) {
  if (text == null) return null;
  const raw = String(text).trim();
  if (!raw) return null;
  const p = Dec.parse(raw.replace(/%/g, "").trim());
  if (!p || p.isNeg()) return null;
  return p.div(100);
}

/** `rate` means 1 source currency unit = X OMR. */
export function convertToOMR(amount, code, rate) {
  if (!amount || amount.isNeg()) return null;
  if (code === "OMR") return amount;
  if (!rate || !rate.gt(0)) return null;
  return amount.mul(rate);
}

/**
 * - CIF: entered directly; no insurance.
 * - CFR: CIF = CFR + 1% insurance.
 * - FOB / EXW: CIF = Cost + Freight + 1% insurance.
 * - Duty = CIF × duty rate; VAT = (CIF + Duty) × VAT rate.
 * - Guarantee = 2% × CIF when documents are not original and CIF > 1,000 OMR.
 * - Bayan documentation = 15 OMR company, 5 OMR personal.
 */
export function calculateDuty(i) {
  const dutyRate = i.dutyRate;
  const vatRate = i.vatRate ?? CONFIG.vatRate;
  if (!dutyRate || dutyRate.isNeg() || vatRate.isNeg()) return null;

  let costOMR = D(0), freightOMR = D(0), insuranceOMR, cif;
  switch (i.deliveryTerm) {
    case "CIF": {
      const v = convertToOMR(i.cif?.amount, i.cif?.currency, i.cif?.rate);
      if (!v) return null;
      cif = v; insuranceOMR = D(0);
      break;
    }
    case "CFR": {
      const v = convertToOMR(i.cfr?.amount, i.cfr?.currency, i.cfr?.rate);
      if (!v) return null;
      insuranceOMR = v.mul(CONFIG.insuranceRate);
      cif = v.add(insuranceOMR);
      break;
    }
    default: {
      const c = convertToOMR(i.cost?.amount, i.cost?.currency, i.cost?.rate);
      const f = convertToOMR(i.freight?.amount, i.freight?.currency, i.freight?.rate);
      if (!c || !f) return null;
      costOMR = c; freightOMR = f;
      const cf = c.add(f);
      insuranceOMR = cf.mul(CONFIG.insuranceRate);
      cif = cf.add(insuranceOMR);
    }
  }

  const duty = cif.mul(dutyRate);
  const vatBase = cif.add(duty);
  const vat = vatBase.mul(vatRate);
  const totalTaxes = duty.add(vat);
  const guarantee = i.documentStatus === "not_original" && cif.gt(CONFIG.documentationGuaranteeThresholdOMR)
    ? cif.mul(CONFIG.documentationGuaranteeRate)
    : D(0);
  const bayan = BAYAN_FEE[i.importerType] ?? BAYAN_FEE.company;
  const total = totalTaxes.add(guarantee).add(bayan);
  const r3 = (d) => d.round(3);

  return {
    deliveryTerm: i.deliveryTerm,
    importerType: i.importerType,
    documentStatus: i.documentStatus,
    costOMR: r3(costOMR),
    freightOMR: r3(freightOMR),
    insuranceOMR: r3(insuranceOMR),
    cifOMR: r3(cif),
    dutyRate,
    dutyOMR: r3(duty),
    vatRate,
    vatBaseOMR: r3(vatBase),
    vatOMR: r3(vat),
    totalTaxesOMR: r3(totalTaxes),
    documentationGuaranteeOMR: r3(guarantee),
    bayanDocumentationOMR: r3(bayan),
    totalPayableOMR: r3(total),
    hsCode: i.hsCode ?? null,
    isEstimate: !!i.isEstimate,
  };
}

// ---------------- Difference calculator ----------------

export function calculateDifference({ mode, amount, condition, currencyCode, rate, convention = "multiply" }) {
  if (!amount || amount.isNeg()) return null;
  const original = mode === "tax_difference" ? amount.div(CONFIG.vatRate) : amount;
  if (!original) return null;
  const adjustment = condition === "duty_and_vat" ? CONFIG.dutyAndVatAdjustment : CONFIG.vatOnlyAdjustment;
  const adjusted = original.sub(adjustment);
  const finalRate = currencyCode === "OMR" ? D(1) : (rate ?? D(1));
  if (!finalRate.gt(0)) return null;
  let finalValue = adjusted;
  if (currencyCode !== "OMR") {
    finalValue = convention === "divide" ? adjusted.div(finalRate) : adjusted.mul(finalRate);
    if (!finalValue) return null;
  }
  return { mode, amount, original, condition, adjustment, adjusted, currencyCode, rate: finalRate, convention, finalValue };
}

// ---------------- Unit converter ----------------

export const UNIT_PAIRS = [
  { id: "carat_gram", dirs: ["carat_to_gram", "gram_to_carat"] },
  { id: "gram_kilogram", dirs: ["gram_to_kilogram", "kilogram_to_gram"] },
  { id: "square_foot_square_meter", dirs: ["square_foot_to_square_meter", "square_meter_to_square_foot"] },
  { id: "pound_kilogram", dirs: ["pound_to_kilogram", "kilogram_to_pound"] },
  { id: "gram_liter", dirs: ["gram_to_liter", "liter_to_gram"] },
];

export const UNIT_DIRS = {
  carat_to_gram: { from: "ct", to: "g" },
  gram_to_carat: { from: "g", to: "ct" },
  gram_to_kilogram: { from: "g", to: "kg" },
  kilogram_to_gram: { from: "kg", to: "g" },
  square_foot_to_square_meter: { from: "ft²", to: "m²" },
  square_meter_to_square_foot: { from: "m²", to: "ft²" },
  pound_to_kilogram: { from: "lb", to: "kg" },
  kilogram_to_pound: { from: "kg", to: "lb" },
  gram_to_liter: { from: "g", to: "L", density: true },
  liter_to_gram: { from: "L", to: "g", density: true },
};

const K = {
  gramsPerCarat: D("0.2"),
  caratsPerGram: D("5.0"),
  gramsPerKilogram: D("1000"),
  sqmPerSqft: D("0.09290304"),
  sqftPerSqm: D("10.7639104167097"),
  kgPerLb: D("0.45359237"),
  lbPerKg: D("2.20462262184878"),
  mlPerL: D("1000"),
};

export function convertUnit(value, dir, density) {
  if (!value || value.isNeg()) return null;
  switch (dir) {
    case "carat_to_gram": return value.mul(K.gramsPerCarat);
    case "gram_to_carat": return value.mul(K.caratsPerGram);
    case "gram_to_kilogram": return value.div(K.gramsPerKilogram);
    case "kilogram_to_gram": return value.mul(K.gramsPerKilogram);
    case "square_foot_to_square_meter": return value.mul(K.sqmPerSqft);
    case "square_meter_to_square_foot": return value.mul(K.sqftPerSqm);
    case "pound_to_kilogram": return value.mul(K.kgPerLb);
    case "kilogram_to_pound": return value.mul(K.lbPerKg);
    case "gram_to_liter":
      if (!density || !density.gt(0)) return null;
      return value.div(density.mul(K.mlPerL));
    case "liter_to_gram":
      if (!density || !density.gt(0)) return null;
      return value.mul(density.mul(K.mlPerL));
  }
  return null;
}

// ---------------- AWB / airlines ----------------

export const TRANSOM_URL = "https://webtrack.omansats.om/shipment-tracking-details";

export const AIRLINES = {
  "910": ["Oman Air Cargo", "WY", "https://cargo.omanair.com/track-shipment"],
  "176": ["Emirates SkyCargo", "EK", "https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer"],
  "157": ["Qatar Airways Cargo", "QR", "https://www.qrcargo.com/s/track-your-shipment"],
  "607": ["Etihad Cargo", "EY", "https://touch.track-trace.com/aircargo"],
  "235": ["Turkish Cargo", "TK", "https://www.turkishcargo.com/en/cargo-tracking"],
  "065": ["Saudia Cargo", "SV", "https://www.saudiacargo.com/en/digital-services?tab=trackShipment"],
  "020": ["Lufthansa Cargo", "LH", "https://www.lufthansa-cargo.com/en/eservices/etracking"],
  "172": ["Cargolux", "CV", "https://www.cargolux.com/track-and-Trace"],
  "071": ["Ethiopian Cargo", "ET", "https://ethiopiancargo.azurewebsites.net/my-cargo/track-your-shipment"],
  "072": ["Gulf Air Cargo", "GF", "https://www.gulfair.com/cargo"],
  "160": ["Cathay Cargo", "CX", "https://www.cathaycargo.com/usrapps/eservices/track/track.aspx"],
  "618": ["Singapore Airlines Cargo", "SQ", "https://www.siacargo.com"],
  "057": ["Air France KLM Martinair Cargo", "AF", "https://www.afklcargo.com/WW/en/homepage/homepage"],
  "074": ["KLM Cargo", "KL", "https://www.afklcargo.com/mycargo/shipment/singlesearch"],
  "125": ["British Airways Cargo", "BA", "https://www.iagcargo.com/en/"],
  "098": ["Air India Cargo", "AI", "https://aicargoportal.airindia.com/icargoneoportal/app/main/#/app"],
  "229": ["Kuwait Airways Cargo", "KU", "https://www.kuwaitairways.com/en/cargo/tracking"],
  "514": ["Air Arabia Cargo", "G9", "https://cargo.airarabia.com/cargo-tracking/"],
  "960": ["SalamAir", "OV", "https://touch.track-trace.com/aircargo"],
};

export const awbDigits = (s) =>
  String(s ?? "")
    .replace(/[٠-٩]/g, (c) => String(c.charCodeAt(0) - 0x660))
    .replace(/[۰-۹]/g, (c) => String(c.charCodeAt(0) - 0x6f0))
    .replace(/\D/g, "");

export const awbFormatted = (s) => {
  const d = awbDigits(s);
  return d.length > 3 ? `${d.slice(0, 3)}-${d.slice(3)}` : d;
};

export function airlineFor(awb) {
  const d = awbDigits(awb);
  if (d.length < 3) return null;
  const a = AIRLINES[d.slice(0, 3)];
  if (!a) return null;
  let url = a[2];
  // Oman Air's no-login SmartKargo page accepts prefix/serial query values.
  if (d.slice(0, 3) === "910" && d.length === 11) {
    url = `https://omanair.smartkargo.com/FrmAWBTracking.aspx?AWBNo=${d.slice(3)}&AWBPrefix=910`;
  }
  return { prefix: d.slice(0, 3), name: a[0], iata: a[1], url };
}
