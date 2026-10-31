# V4.3.3 — Bilingual HS Subheadings

- Fixed the hierarchy audit bug that populated almost all subheading labels in English only.
- Arabic subheading wording is sourced from the supplied Official Oman Customs Tariff 2026 PDF, page-aligned with each tariff record.
- 11,606 production rows now carry an official Arabic subheading label alongside English.
- 596 rows where the Arabic parent label could not be resolved safely are intentionally not shown as a subheading node; the app never substitutes an English-only node in Arabic mode and never machine-translates customs wording.
- Examples verified: 4301.90 → «رؤوس، ذيول، أقدام أو أجزاء أُخر أو قطع صالحة للاستعمال في صناعة الفراء»; 4303.10 → «ألبسة ولوازم ألبسة»; 8537.10 → «لجهد (توتر) لا يزيد عن 1,000 فولت (V)».
