import { useEffect, useMemo, useState } from "react";

import { fetchAccounts } from "../api/accounts";
import {
  deleteTransaction,
  fetchTransactions,
  updateTransaction
} from "../api/transactions";

const CHART_COLORS = [
  "#7C9CFF",
  "#4FD1C5",
  "#F59E0B",
  "#FB7185",
  "#A78BFA",
  "#34D399"
];

const FIXED_KEYWORDS = [
  "abonelik",
  "kira",
  "fatura",
  "internet",
  "telefon",
  "aidat",
  "odeme",
  "sigorta"
];

const INITIAL_EDIT_FORM = {
  account_id: "",
  category_name: "",
  type: "expense",
  amount: "",
  description: "",
  note: "",
  occurred_at: ""
};

const INITIAL_ANALYSIS_FILTERS = {
  segment: "all",
  category: "",
  dateFrom: "",
  dateTo: ""
};

function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

function formatPercent(value) {
  return `${value >= 0 ? "+" : ""}${value.toFixed(0)}%`;
}

function formatDate(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatStatementMonth(value) {
  if (!value) {
    return "Yok";
  }

  return new Intl.DateTimeFormat("tr-TR", {
    month: "long",
    year: "numeric"
  }).format(new Date(`${value}T00:00:00`));
}

function formatMonthLabel(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    month: "long",
    year: "numeric"
  }).format(new Date(value));
}

function toDateTimeLocal(value) {
  const date = new Date(value);
  const offsetDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return offsetDate.toISOString().slice(0, 16);
}

function getTypeLabel(type) {
  if (type === "income") {
    return "Gelir";
  }
  if (type === "payment") {
    return "Odeme";
  }
  return "Harcama";
}

function normalizeLabel(value, fallback = "Diger") {
  return value?.trim() || fallback;
}

function normalizeKey(value) {
  return normalizeLabel(value).toLocaleLowerCase("tr-TR");
}

function startOfDay(value) {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
}

function endOfDay(value) {
  const date = new Date(value);
  date.setHours(23, 59, 59, 999);
  return date;
}

function getCategoryAppearance(categoryName, type) {
  const normalized = (categoryName ?? "").trim().toLowerCase();

  if (type === "income") {
    return {
      icon: "+",
      tone: "income",
      label: categoryName ?? "Gelir"
    };
  }

  if (type === "payment") {
    return {
      icon: "OD",
      tone: "payment",
      label: categoryName ?? "Odeme"
    };
  }

  if (normalized.includes("market")) {
    return { icon: "MK", tone: "market", label: categoryName };
  }
  if (
    normalized.includes("kahve") ||
    normalized.includes("kafe") ||
    normalized.includes("yeme") ||
    normalized.includes("yemek")
  ) {
    return { icon: "KF", tone: "food", label: categoryName };
  }
  if (
    normalized.includes("fatura") ||
    normalized.includes("abonelik") ||
    normalized.includes("kira")
  ) {
    return { icon: "FT", tone: "bill", label: categoryName };
  }
  if (normalized.includes("ulasim") || normalized.includes("taksi") || normalized.includes("yakit")) {
    return { icon: "UL", tone: "transport", label: categoryName };
  }
  if (normalized.includes("saglik") || normalized.includes("dis") || normalized.includes("eczane")) {
    return { icon: "SG", tone: "health", label: categoryName };
  }

  return {
    icon: type === "expense" ? "HR" : "DI",
    tone: type === "expense" ? "expense" : "neutral",
    label: categoryName ?? "Diger"
  };
}

function buildTrendPath(values, width, height, padding, maxValue) {
  if (!values.length) {
    return "";
  }

  const innerWidth = width - padding * 2;
  const innerHeight = height - padding * 2;

  return values
    .map((value, index) => {
      const x = padding + (values.length === 1 ? innerWidth / 2 : (innerWidth / (values.length - 1)) * index);
      const y = height - padding - (maxValue ? (value / maxValue) * innerHeight : 0);
      return `${index === 0 ? "M" : "L"} ${x} ${y}`;
    })
    .join(" ");
}

function buildAreaPath(values, width, height, padding, maxValue) {
  if (!values.length) {
    return "";
  }

  const line = buildTrendPath(values, width, height, padding, maxValue);
  const innerWidth = width - padding * 2;
  const lastX =
    padding + (values.length === 1 ? innerWidth / 2 : (innerWidth / (values.length - 1)) * (values.length - 1));

  return `${line} L ${lastX} ${height - padding} L ${padding} ${height - padding} Z`;
}

function buildDonutBackground(segments) {
  if (!segments.length) {
    return "conic-gradient(rgba(157, 167, 179, 0.18) 0deg 360deg)";
  }

  let start = 0;
  const stops = segments.map((segment) => {
    const end = start + segment.share * 360;
    const stop = `${segment.color} ${start}deg ${end}deg`;
    start = end;
    return stop;
  });

  return `conic-gradient(${stops.join(", ")})`;
}

function TrendChart({ months }) {
  if (!months.length) {
    return <p className="muted-text">Trend grafigi icin yeterli veri yok.</p>;
  }

  const width = 360;
  const height = 220;
  const padding = 22;
  const incomeValues = months.map((month) => month.income);
  const outgoingValues = months.map((month) => month.outgoing);
  const maxValue = Math.max(...incomeValues, ...outgoingValues, 1);

  return (
    <div className="history-trend-chart">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="history-trend-chart__svg"
        role="img"
        aria-label="Aylik gelir ve gider grafigi"
      >
        {[0.25, 0.5, 0.75, 1].map((step) => {
          const y = height - padding - (height - padding * 2) * step;
          return <line key={step} x1={padding} x2={width - padding} y1={y} y2={y} className="history-trend-chart__grid" />;
        })}
        <path
          d={buildAreaPath(outgoingValues, width, height, padding, maxValue)}
          className="history-trend-chart__area"
        />
        <path
          d={buildTrendPath(incomeValues, width, height, padding, maxValue)}
          className="history-trend-chart__line history-trend-chart__line--income"
        />
        <path
          d={buildTrendPath(outgoingValues, width, height, padding, maxValue)}
          className="history-trend-chart__line history-trend-chart__line--outgoing"
        />
        {months.map((month, index) => {
          const innerWidth = width - padding * 2;
          const x = padding + (months.length === 1 ? innerWidth / 2 : (innerWidth / (months.length - 1)) * index);
          const incomeY = height - padding - (month.income / maxValue) * (height - padding * 2);
          const outgoingY = height - padding - (month.outgoing / maxValue) * (height - padding * 2);
          return (
            <g key={month.key}>
              <circle cx={x} cy={incomeY} r="4.5" className="history-trend-chart__dot history-trend-chart__dot--income" />
              <circle cx={x} cy={outgoingY} r="4.5" className="history-trend-chart__dot history-trend-chart__dot--outgoing" />
            </g>
          );
        })}
      </svg>

      <div className="history-trend-chart__legend">
        <span><i className="history-trend-chart__swatch history-trend-chart__swatch--income" /> Gelir</span>
        <span><i className="history-trend-chart__swatch history-trend-chart__swatch--outgoing" /> Gider</span>
      </div>

      <div className="history-trend-chart__months">
        {months.map((month) => (
          <article className="history-trend-chart__month" key={month.key}>
            <span>{month.shortLabel}</span>
            <strong>{formatMoney(month.net)}</strong>
            <small>Net</small>
          </article>
        ))}
      </div>
    </div>
  );
}

function DonutChart({ categories, totalOutgoing }) {
  const donutSegments = categories.map((category, index) => ({
    ...category,
    share: totalOutgoing > 0 ? category.total / totalOutgoing : 0,
    color: CHART_COLORS[index % CHART_COLORS.length]
  }));

  return (
    <div className="history-donut">
      <div
        className="history-donut__ring"
        style={{ background: buildDonutBackground(donutSegments) }}
        aria-hidden="true"
      >
        <div className="history-donut__center">
          <span>Toplam</span>
          <strong>{formatMoney(totalOutgoing)}</strong>
        </div>
      </div>

      <div className="history-donut__legend">
        {donutSegments.length ? (
          donutSegments.map((segment) => (
            <article className="history-donut__legend-item" key={segment.key}>
              <div className="history-donut__legend-main">
                <i style={{ backgroundColor: segment.color }} />
                <strong>{segment.label}</strong>
              </div>
              <div className="history-donut__legend-meta">
                <span>{formatMoney(segment.total)}</span>
                <span>%{Math.round(segment.share * 100)}</span>
              </div>
            </article>
          ))
        ) : (
          <p className="muted-text">Kategori dagilimi icin harcama verisi yok.</p>
        )}
      </div>
    </div>
  );
}

export default function HistoryPage() {
  const [accounts, setAccounts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [filters, setFilters] = useState({
    accountId: "",
    type: "",
    search: ""
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editingId, setEditingId] = useState(null);
  const [detailId, setDetailId] = useState(null);
  const [activeArchive, setActiveArchive] = useState("months");
  const [searchOpen, setSearchOpen] = useState(false);
  const [editForm, setEditForm] = useState(INITIAL_EDIT_FORM);
  const [analysisFilters, setAnalysisFilters] = useState(INITIAL_ANALYSIS_FILTERS);

  const accountMap = useMemo(
    () => new Map(accounts.map((account) => [account.id, account])),
    [accounts]
  );

  const categoryOptions = useMemo(
    () => [...new Set(
      transactions
        .map((transaction) => normalizeLabel(transaction.category_name, "Diger"))
        .filter(Boolean)
    )].sort((left, right) => left.localeCompare(right, "tr")),
    [transactions]
  );

  const filteredTransactions = useMemo(() => {
    const now = new Date();
    const segmentStart = (() => {
      if (analysisFilters.segment === "month") {
        return new Date(now.getFullYear(), now.getMonth(), 1);
      }
      if (analysisFilters.segment === "quarter") {
        return new Date(now.getFullYear(), now.getMonth(), now.getDate() - 89);
      }
      if (analysisFilters.segment === "year") {
        return new Date(now.getFullYear(), 0, 1);
      }
      return null;
    })();

    const fromDate = analysisFilters.dateFrom ? startOfDay(analysisFilters.dateFrom) : null;
    const toDate = analysisFilters.dateTo ? endOfDay(analysisFilters.dateTo) : null;
    const selectedCategory = analysisFilters.category.trim()
      ? normalizeKey(analysisFilters.category)
      : "";

    return transactions.filter((transaction) => {
      const occurredAt = new Date(transaction.occurred_at);
      const transactionCategory = normalizeKey(transaction.category_name);

      if (segmentStart && occurredAt < segmentStart) {
        return false;
      }
      if (fromDate && occurredAt < fromDate) {
        return false;
      }
      if (toDate && occurredAt > toDate) {
        return false;
      }
      if (selectedCategory && transactionCategory !== selectedCategory) {
        return false;
      }

      return true;
    });
  }, [analysisFilters, transactions]);

  const historyOverview = useMemo(() => {
    const monthMap = new Map();
    const yearMap = new Map();
    const categoryMap = new Map();
    const signatureMap = new Map();
    const outgoingRecords = [];
    let totalIncome = 0;
    let totalOutgoing = 0;
    let totalPayments = 0;
    let largestExpense = null;
    let expenseCount = 0;

    for (const transaction of filteredTransactions) {
      const date = new Date(transaction.occurred_at);
      const monthKey = `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
      const monthDate = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
      const yearKey = String(date.getUTCFullYear());
      const amount = Number(transaction.amount ?? 0);
      const isIncome = transaction.type === "income";
      const isPayment = transaction.type === "payment";
      const categoryLabel = normalizeLabel(transaction.category_name, isIncome ? "Gelir" : "Diger");
      const categoryKey = normalizeKey(categoryLabel);

      if (!monthMap.has(monthKey)) {
        monthMap.set(monthKey, {
          key: monthKey,
          label: formatMonthLabel(monthDate),
          shortLabel: new Intl.DateTimeFormat("tr-TR", { month: "short" }).format(monthDate),
          sortValue: monthDate.getTime(),
          income: 0,
          outgoing: 0,
          net: 0,
          categories: new Map()
        });
      }

      if (!yearMap.has(yearKey)) {
        yearMap.set(yearKey, {
          key: yearKey,
          label: `${yearKey} Ozeti`,
          income: 0,
          outgoing: 0,
          net: 0,
          count: 0
        });
      }

      const monthBucket = monthMap.get(monthKey);
      const yearBucket = yearMap.get(yearKey);

      yearBucket.count += 1;

      if (isIncome) {
        monthBucket.income += amount;
        monthBucket.net += amount;
        yearBucket.income += amount;
        yearBucket.net += amount;
        totalIncome += amount;
        continue;
      }

      if (isPayment) {
        totalPayments += amount;
        continue;
      }

      monthBucket.outgoing += amount;
      monthBucket.net -= amount;
      yearBucket.outgoing += amount;
      yearBucket.net -= amount;
      totalOutgoing += amount;

      monthBucket.categories.set(
        categoryKey,
        (monthBucket.categories.get(categoryKey) ?? 0) + amount
      );

      if (!categoryMap.has(categoryKey)) {
        categoryMap.set(categoryKey, {
          key: categoryKey,
          label: categoryLabel,
          total: 0,
          count: 0,
          months: new Map()
        });
      }

      const categoryBucket = categoryMap.get(categoryKey);
      categoryBucket.total += amount;
      categoryBucket.count += 1;
      categoryBucket.months.set(monthKey, (categoryBucket.months.get(monthKey) ?? 0) + amount);

      const signature = `${categoryKey}::${normalizeKey(transaction.description)}`;
      if (!signatureMap.has(signature)) {
        signatureMap.set(signature, new Set());
      }
      signatureMap.get(signature).add(monthKey);

      outgoingRecords.push({
        transaction,
        amount,
        signature,
        categoryKey
      });

      if (transaction.type === "expense") {
        expenseCount += 1;
        if (!largestExpense || amount > largestExpense.amount) {
          largestExpense = {
            amount,
            description: transaction.description
          };
        }
      }
    }

    const allMonths = [...monthMap.values()].sort((left, right) => right.sortValue - left.sortValue);
    const allYears = [...yearMap.values()].sort((left, right) => Number(right.key) - Number(left.key));
    const allMonthsChronological = [...allMonths].reverse();
    const recentMonths = allMonths.slice(0, 4);
    const recentYears = allYears.slice(0, 2);
    const trendMonths = [...allMonths].slice(0, 6).reverse();
    const bestMonth = [...allMonths].sort((left, right) => right.net - left.net)[0] ?? null;
    const worstMonth = [...allMonths].sort((left, right) => left.net - right.net)[0] ?? null;
    const categoryBreakdown = [...categoryMap.values()].sort((left, right) => right.total - left.total);
    const donutCategories = categoryBreakdown.slice(0, 4);

    if (categoryBreakdown.length > 4) {
      const otherTotal = categoryBreakdown.slice(4).reduce((sum, item) => sum + item.total, 0);
      donutCategories.push({
        key: "other",
        label: "Diger",
        total: otherTotal,
        count: categoryBreakdown.slice(4).reduce((sum, item) => sum + item.count, 0),
        months: new Map()
      });
    }

    let fixedOutgoing = 0;
    let variableOutgoing = 0;

    for (const record of outgoingRecords) {
      const signatureMonths = signatureMap.get(record.signature)?.size ?? 0;
      const transactionText = `${record.transaction.description} ${record.transaction.category_name ?? ""}`.toLowerCase();
      const isFixed =
        record.transaction.type === "payment" ||
        FIXED_KEYWORDS.some((keyword) => transactionText.includes(keyword)) ||
        signatureMonths >= 2;

      if (isFixed) {
        fixedOutgoing += record.amount;
      } else {
        variableOutgoing += record.amount;
      }
    }

    const currentMonth = allMonths[0] ?? null;
    const previousMonth = allMonths[1] ?? null;
    const currentYear = allYears[0] ?? null;
    const previousYear = allYears[1] ?? null;
    const monthlyChange = previousMonth?.outgoing
      ? ((currentMonth?.outgoing ?? 0) - previousMonth.outgoing) / previousMonth.outgoing * 100
      : 0;
    const yearlyChange = previousYear?.outgoing
      ? ((currentYear?.outgoing ?? 0) - previousYear.outgoing) / previousYear.outgoing * 100
      : 0;

    const volatileCategory = categoryBreakdown
      .map((category) => {
        const monthValues = allMonthsChronological.map((month) => month.categories.get(category.key) ?? 0);
        const max = Math.max(...monthValues, 0);
        const min = Math.min(...monthValues, 0);
        const average = monthValues.reduce((sum, value) => sum + value, 0) / (monthValues.length || 1);
        return {
          ...category,
          volatility: average > 0 ? (max - min) / average : 0
        };
      })
      .sort((left, right) => right.volatility - left.volatility)[0] ?? null;

    const topCategory = categoryBreakdown[0] ?? null;
    const lightestCategory = categoryBreakdown[categoryBreakdown.length - 1] ?? null;
    const savingsRate = totalIncome > 0 ? ((totalIncome - totalOutgoing) / totalIncome) * 100 : 0;
    const fixedRatio = totalOutgoing > 0 ? (fixedOutgoing / totalOutgoing) * 100 : 0;
    const variableRatio = totalOutgoing > 0 ? (variableOutgoing / totalOutgoing) * 100 : 0;

    const recommendations = [];

    if (currentMonth && previousMonth && monthlyChange > 8) {
      recommendations.push(
        `${currentMonth.label} giderin bir onceki aya gore ${formatPercent(monthlyChange)} artmis. ${topCategory?.label ?? "En yuksek kategori"} harcamasina limit koymak mantikli.`
      );
    }

    if (fixedRatio > 55) {
      recommendations.push(
        `Sabit giderlerin toplam cikisinin %${fixedRatio.toFixed(0)} seviyesinde. Abonelik, odeme ve zorunlu kalemleri ayri bir limit havuzunda takip et.`
      );
    }

    if (volatileCategory && volatileCategory.volatility > 0.8) {
      recommendations.push(
        `${volatileCategory.label} kategorisi en degisken kalemin. Bu kategori icin haftalik ust limit belirlemek oynakligi azaltabilir.`
      );
    }

    if (savingsRate < 15) {
      recommendations.push(
        `Tasarruf oranin %${savingsRate.toFixed(0)} seviyesinde. Degisken harcamalari kisip gelire oranla en az %20 bosluk acmak saglikli olur.`
      );
    }

    if (!recommendations.length) {
      recommendations.push(
        "Dagilim dengeli gorunuyor. Bu dengeyi korumak icin degisken harcamalari haftalik takip etmeye devam et."
      );
    }

    return {
      recentMonths,
      recentYears,
      allMonths,
      allYears,
      trendMonths,
      donutCategories,
      analysis: {
        totalIncome,
        totalOutgoing,
        totalPayments,
        net: totalIncome - totalOutgoing,
        averageExpense: expenseCount ? totalOutgoing / expenseCount : 0,
        savingsRate,
        largestExpense,
        bestMonth,
        worstMonth,
        topCategory,
        lightestCategory,
        currentMonth,
        previousMonth,
        currentYear,
        previousYear,
        monthlyChange,
        yearlyChange,
        fixedOutgoing,
        variableOutgoing,
        fixedRatio,
        variableRatio,
        volatileCategory
      },
      recommendations
    };
  }, [filteredTransactions]);

  async function loadData(nextFilters = filters) {
    setLoading(true);
    setError("");

    try {
      const [accountsPayload, transactionsPayload] = await Promise.all([
        fetchAccounts(),
        fetchTransactions(nextFilters)
      ]);
      setAccounts(accountsPayload);
      setTransactions(transactionsPayload);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  function handleFilterChange(field, value) {
    setFilters((current) => ({
      ...current,
      [field]: value
    }));
  }

  function handleAnalysisFilterChange(field, value) {
    setAnalysisFilters((current) => ({
      ...current,
      [field]: value
    }));
  }

  function resetAnalysisFilters() {
    setAnalysisFilters(INITIAL_ANALYSIS_FILTERS);
  }

  async function applyFilters(event) {
    event.preventDefault();
    await loadData(filters);
  }

  function startEditing(transaction) {
    setEditingId(transaction.id);
    setDetailId(null);
    setEditForm({
      account_id: String(transaction.account_id),
      category_name: transaction.category_name ?? "",
      type: transaction.type,
      amount: String(transaction.amount ?? ""),
      description: transaction.description,
      note: transaction.note ?? "",
      occurred_at: toDateTimeLocal(transaction.occurred_at)
    });
  }

  function cancelEditing() {
    setEditingId(null);
    setEditForm(INITIAL_EDIT_FORM);
  }

  async function handleSave(transactionId) {
    try {
      setError("");
      await updateTransaction(transactionId, {
        account_id: Number(editForm.account_id),
        category_name: editForm.category_name.trim() || null,
        type: editForm.type,
        amount: editForm.amount,
        description: editForm.description.trim(),
        note: editForm.note.trim() || null,
        occurred_at: new Date(editForm.occurred_at).toISOString()
      });
      cancelEditing();
      await loadData();
    } catch (nextError) {
      setError(nextError.message);
    }
  }

  async function handleDelete(transactionId) {
    try {
      setError("");
      await deleteTransaction(transactionId);
      if (editingId === transactionId) {
        cancelEditing();
      }
      await loadData();
    } catch (nextError) {
      setError(nextError.message);
    }
  }

  return (
    <main className="shell">
      <section className="accounts-panel history-hero-panel">
        <div className="accounts-panel__header">
          <div>
            <p className="status-card__eyebrow">Analiz</p>
            <h1 className="history-hero-panel__title">Finans Analizi</h1>
            <p className="accounts-panel__meta">
              Aylar, yillar ve kategori davranislarin tek bakista gorunsun.
            </p>
          </div>
          <div className="history-hero-panel__badge-stack">
            <span className="history-summary-pill">
              {historyOverview.analysis.currentMonth?.label ?? "Bu ay"} · {filteredTransactions.length} kayit
            </span>
            <span className="history-summary-pill history-summary-pill--soft">
              Net {formatMoney(historyOverview.analysis.net)}
            </span>
          </div>
        </div>

        <div className="history-hero-layout">
          <div className="history-hero-main">
            <article className="history-metric-card history-metric-card--primary history-metric-card--hero">
              <span>Toplam net durum</span>
              <strong>{formatMoney(historyOverview.analysis.net)}</strong>
              <p>
                Gelir {formatMoney(historyOverview.analysis.totalIncome)} ·
                Gider {formatMoney(historyOverview.analysis.totalOutgoing)}
              </p>
              {historyOverview.analysis.totalPayments > 0 ? (
                <p>Kart odemeleri ayri izleniyor: {formatMoney(historyOverview.analysis.totalPayments)}</p>
              ) : null}
            </article>

            <div className="history-analysis-toolbar">
              <div className="history-segmented-control" role="tablist" aria-label="Analiz donemi">
                {[
                  { id: "all", label: "Tum Zaman" },
                  { id: "month", label: "Bu Ay" },
                  { id: "quarter", label: "Son 90 Gun" },
                  { id: "year", label: "Bu Yil" }
                ].map((segment) => (
                  <button
                    key={segment.id}
                    className={`ghost-button ${analysisFilters.segment === segment.id ? "ghost-button--active" : ""}`}
                    type="button"
                    onClick={() => handleAnalysisFilterChange("segment", segment.id)}
                  >
                    {segment.label}
                  </button>
                ))}
              </div>

              <div className="history-deep-filters">
                <div className="history-filter-field">
                  <label className="compose-form__label" htmlFor="history-category-filter">
                    Kategori
                  </label>
                  <select
                    id="history-category-filter"
                    className="compose-form__input"
                    value={analysisFilters.category}
                    onChange={(event) => handleAnalysisFilterChange("category", event.target.value)}
                  >
                    <option value="">Tum kategoriler</option>
                    {categoryOptions.map((category) => (
                      <option key={category} value={category}>
                        {category}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="history-filter-field">
                  <label className="compose-form__label" htmlFor="history-date-from">
                    Baslangic
                  </label>
                  <input
                    id="history-date-from"
                    className="compose-form__input"
                    type="date"
                    value={analysisFilters.dateFrom}
                    onChange={(event) => handleAnalysisFilterChange("dateFrom", event.target.value)}
                  />
                </div>

                <div className="history-filter-field">
                  <label className="compose-form__label" htmlFor="history-date-to">
                    Bitis
                  </label>
                  <input
                    id="history-date-to"
                    className="compose-form__input"
                    type="date"
                    value={analysisFilters.dateTo}
                    onChange={(event) => handleAnalysisFilterChange("dateTo", event.target.value)}
                  />
                </div>

                <div className="history-filter-field history-filter-field--action">
                  <span className="compose-form__label">Filtre</span>
                  <button className="ghost-button" type="button" onClick={resetAnalysisFilters}>
                    Sifirla
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div className="history-hero-grid">
            <article className="history-metric-card">
              <span>Bu ay degisim</span>
              <strong>{formatPercent(historyOverview.analysis.monthlyChange)}</strong>
              <p>
                {historyOverview.analysis.currentMonth?.label ?? "Bu ay"} gideri onceki aya gore
              </p>
            </article>

            <article className="history-metric-card">
              <span>Tasarruf orani</span>
              <strong>%{historyOverview.analysis.savingsRate.toFixed(0)}</strong>
              <p>Gelire gore bosluk seviyesi</p>
            </article>

            <article className="history-metric-card">
              <span>En yuksek kategori</span>
              <strong>{historyOverview.analysis.topCategory?.label ?? "Veri yok"}</strong>
              <p>
                {historyOverview.analysis.topCategory
                  ? formatMoney(historyOverview.analysis.topCategory.total)
                  : "Harcama yok"}
              </p>
            </article>

            <article className="history-metric-card">
              <span>Ortalama cikis</span>
              <strong>{formatMoney(historyOverview.analysis.averageExpense)}</strong>
              <p>Islem basina ortalama gider seviyesi</p>
            </article>

            <article className="history-metric-card">
              <span>Kart odemeleri</span>
              <strong>{formatMoney(historyOverview.analysis.totalPayments)}</strong>
              <p>Gider toplamindan ayri tutulur</p>
            </article>
          </div>
        </div>
      </section>

      <section className="history-analysis-grid">
        <article className="history-chart-card">
          <div className="history-chart-card__header">
            <div>
              <p className="status-card__eyebrow">Aylik Akis</p>
              <h2>Gelir ve gider trendi</h2>
            </div>
            <span className="history-summary-pill history-summary-pill--soft">
              Son {historyOverview.trendMonths.length || 0} ay
            </span>
          </div>
          <TrendChart months={historyOverview.trendMonths} />
        </article>

        <article className="history-chart-card">
          <div className="history-chart-card__header">
            <div>
              <p className="status-card__eyebrow">Kategori Dagilimi</p>
              <h2>Daire grafik ile cikislar</h2>
            </div>
            <span className="history-summary-pill history-summary-pill--soft">
              En yogun kategoriler
            </span>
          </div>
          <DonutChart
            categories={historyOverview.donutCategories}
            totalOutgoing={historyOverview.analysis.totalOutgoing}
          />
        </article>
      </section>

      <section className="history-behavior-grid">
        <article className="accounts-panel history-behavior-card">
          <div className="accounts-panel__header">
            <div>
              <p className="status-card__eyebrow">Harcama Davranisi</p>
              <p className="accounts-panel__meta">Sabit ve degisken cikislarini ayir</p>
            </div>
          </div>

          <div className="history-split-bars">
            <article className="history-split-bar-card">
              <div className="history-split-bar-card__head">
                <span>Sabit giderler</span>
                <strong>%{historyOverview.analysis.fixedRatio.toFixed(0)}</strong>
              </div>
              <div className="history-progress">
                <span style={{ width: `${Math.min(historyOverview.analysis.fixedRatio, 100)}%` }} />
              </div>
              <p>{formatMoney(historyOverview.analysis.fixedOutgoing)}</p>
            </article>

            <article className="history-split-bar-card">
              <div className="history-split-bar-card__head">
                <span>Degisken giderler</span>
                <strong>%{historyOverview.analysis.variableRatio.toFixed(0)}</strong>
              </div>
              <div className="history-progress history-progress--variable">
                <span style={{ width: `${Math.min(historyOverview.analysis.variableRatio, 100)}%` }} />
              </div>
              <p>{formatMoney(historyOverview.analysis.variableOutgoing)}</p>
            </article>
          </div>

          <div className="history-insight-grid history-insight-grid--analysis">
            <article className="history-insight-card">
              <span>En zor ay</span>
              <strong>
                {historyOverview.analysis.worstMonth
                  ? `${historyOverview.analysis.worstMonth.label} · ${formatMoney(historyOverview.analysis.worstMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-insight-card">
              <span>En rahat ay</span>
              <strong>
                {historyOverview.analysis.bestMonth
                  ? `${historyOverview.analysis.bestMonth.label} · ${formatMoney(historyOverview.analysis.bestMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-insight-card">
              <span>En degisken kategori</span>
              <strong>{historyOverview.analysis.volatileCategory?.label ?? "Veri yok"}</strong>
            </article>
            <article className="history-insight-card">
              <span>En buyuk harcama</span>
              <strong>
                {historyOverview.analysis.largestExpense
                  ? `${historyOverview.analysis.largestExpense.description} · ${formatMoney(historyOverview.analysis.largestExpense.amount)}`
                  : "Harcama yok"}
              </strong>
            </article>
          </div>
        </article>

        <article className="accounts-panel history-behavior-card">
          <div className="accounts-panel__header">
            <div>
              <p className="status-card__eyebrow">Oneriler</p>
              <p className="accounts-panel__meta">Fazla ve az harcama sinyallerin</p>
            </div>
          </div>

          <div className="history-recommendation-list">
            {historyOverview.recommendations.map((recommendation, index) => (
              <article className="history-recommendation-card" key={recommendation}>
                <span>{String(index + 1).padStart(2, "0")}</span>
                <p>{recommendation}</p>
              </article>
            ))}
          </div>

          <div className="history-year-grid">
            {historyOverview.recentYears.length ? (
              historyOverview.recentYears.map((year) => (
                <article className="history-year-card" key={year.key}>
                  <p className="history-year-card__title">{year.label}</p>
                  <strong>{formatMoney(year.net)}</strong>
                  <div className="history-year-card__meta">
                    <span>Gelir {formatMoney(year.income)}</span>
                    <span>Gider {formatMoney(year.outgoing)}</span>
                    <span>{year.count} islem</span>
                  </div>
                </article>
              ))
            ) : (
              <p className="muted-text">Yillik ozet icin veri yok.</p>
            )}
          </div>
        </article>
      </section>

      <section className="accounts-panel">
        <div className="accounts-panel__header">
          <div>
            <p className="status-card__eyebrow">
              {activeArchive === "years" ? "Yillik Arsiv" : "Aylik Arsiv"}
            </p>
            <p className="accounts-panel__meta">
              {activeArchive === "years"
                ? "Tum yillarin ozetleri ve eski analizler"
                : "Tum aylarin ozetleri ve eski analizler"}
            </p>
          </div>
          <div className="history-archive-switch">
            <button
              className={`ghost-button ${activeArchive === "months" ? "ghost-button--active" : ""}`}
              type="button"
              onClick={() => setActiveArchive("months")}
            >
              Aylar
            </button>
            <button
              className={`ghost-button ${activeArchive === "years" ? "ghost-button--active" : ""}`}
              type="button"
              onClick={() => setActiveArchive("years")}
            >
              Yillar
            </button>
          </div>
        </div>

        <div className="history-archive-layout">
          <div className="history-archive-list">
            {(activeArchive === "years" ? historyOverview.allYears : historyOverview.allMonths).length ? (
              (activeArchive === "years" ? historyOverview.allYears : historyOverview.allMonths).map((entry) => (
                <article className="history-archive-row" key={entry.key}>
                  <div>
                    <strong>{entry.label}</strong>
                    <p>Net {formatMoney(entry.net)}</p>
                  </div>
                  <div className="history-archive-row__meta">
                    <span>Gelen {formatMoney(entry.income)}</span>
                    <span>Giden {formatMoney(entry.outgoing)}</span>
                    {"count" in entry ? <span>{entry.count} islem</span> : null}
                  </div>
                </article>
              ))
            ) : null}
          </div>

          <aside className="history-archive-aside">
            <article className="history-archive-note">
              <span>En yuksek harcama</span>
              <strong>
                {historyOverview.analysis.largestExpense
                  ? `${historyOverview.analysis.largestExpense.description} · ${formatMoney(historyOverview.analysis.largestExpense.amount)}`
                  : "Harcama yok"}
              </strong>
            </article>
            <article className="history-archive-note">
              <span>En iyi ay</span>
              <strong>
                {historyOverview.analysis.bestMonth
                  ? `${historyOverview.analysis.bestMonth.label} · ${formatMoney(historyOverview.analysis.bestMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-archive-note">
              <span>En zor ay</span>
              <strong>
                {historyOverview.analysis.worstMonth
                  ? `${historyOverview.analysis.worstMonth.label} · ${formatMoney(historyOverview.analysis.worstMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-archive-note">
              <span>Yillik degisim</span>
              <strong>{formatPercent(historyOverview.analysis.yearlyChange)}</strong>
            </article>
          </aside>
        </div>
      </section>

      <section className="accounts-panel">
        <div className="accounts-panel__header">
          <div>
            <p className="status-card__eyebrow">Arama ve Filtre</p>
            <p className="accounts-panel__meta">Islemleri asagidan tarayabilirsin</p>
          </div>
          <button
            className={`ghost-button ${searchOpen ? "ghost-button--active" : ""}`}
            type="button"
            onClick={() => setSearchOpen((current) => !current)}
          >
            {searchOpen ? "Aramayi Gizle" : "Arama"}
          </button>
        </div>
        {searchOpen ? (
          <form className="history-filters" onSubmit={applyFilters}>
            <label className="compose-form__label" htmlFor="history-account">
              Hesap
            </label>
            <select
              id="history-account"
              className="compose-form__input"
              value={filters.accountId}
              onChange={(event) => handleFilterChange("accountId", event.target.value)}
            >
              <option value="">Tum hesaplar</option>
              {accounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.name}
                </option>
              ))}
            </select>

            <label className="compose-form__label" htmlFor="history-type">
              Tur
            </label>
            <select
              id="history-type"
              className="compose-form__input"
              value={filters.type}
              onChange={(event) => handleFilterChange("type", event.target.value)}
            >
              <option value="">Tum hareketler</option>
              <option value="expense">Harcama</option>
              <option value="income">Gelir</option>
              <option value="payment">Odeme</option>
            </select>

            <label className="compose-form__label" htmlFor="history-search">
              Ara
            </label>
            <input
              id="history-search"
              className="compose-form__input"
              placeholder="Kahve, kira, maas"
              value={filters.search}
              onChange={(event) => handleFilterChange("search", event.target.value)}
            />

            <button className="primary-button" type="submit">
              Uygula
            </button>
          </form>
        ) : null}
      </section>

      {loading ? <section className="account-list"><article className="account-card">Yukleniyor...</article></section> : null}
      {error ? <p className="error-banner">{error}</p> : null}

      <section className="history-list">
        {filteredTransactions.map((transaction) => {
          const account = accountMap.get(transaction.account_id);
          const isEditing = editingId === transaction.id;
          const isShowingDetail = detailId === transaction.id;
          const categoryAppearance = getCategoryAppearance(
            transaction.category_name,
            transaction.type
          );

          return (
            <article className="transaction-card" key={transaction.id}>
              <div className="transaction-card__header">
                <div>
                  <div className="transaction-card__topline">
                    <strong>{transaction.description}</strong>
                    <span className={`transaction-badge transaction-badge--${transaction.type}`}>
                      {getTypeLabel(transaction.type)}
                    </span>
                  </div>
                  <p>
                    {account?.name ?? `Hesap #${transaction.account_id}`} · {formatDate(transaction.occurred_at)}
                  </p>
                </div>
                <strong>{formatMoney(transaction.amount)}</strong>
              </div>

              {!isEditing ? (
                <div className="account-card__meta">
                  {transaction.category_name ? (
                    <span
                      aria-label={`Kategori ${transaction.category_name}`}
                      className={`category-chip category-chip--${categoryAppearance.tone}`}
                    >
                      <span className="category-chip__icon" aria-hidden="true">
                        {categoryAppearance.icon}
                      </span>
                      <span>{categoryAppearance.label}</span>
                    </span>
                  ) : null}
                  {transaction.note ? <span>Not {transaction.note}</span> : null}
                </div>
              ) : null}

              {!isEditing && isShowingDetail ? (
                <section className="transaction-detail-card">
                  <div className="transaction-detail-card__grid">
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Hesap</span>
                      <strong>{account?.name ?? `Hesap #${transaction.account_id}`}</strong>
                    </article>
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Tur</span>
                      <strong>{getTypeLabel(transaction.type)}</strong>
                    </article>
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Kategori</span>
                      <strong>{transaction.category_name ?? "Yok"}</strong>
                    </article>
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Zaman</span>
                      <strong>{formatDate(transaction.occurred_at)}</strong>
                    </article>
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Ekstre Ayi</span>
                      <strong>{formatStatementMonth(transaction.statement_month)}</strong>
                    </article>
                    <article className="transaction-detail-card__item">
                      <span className="transaction-detail-card__label">Not</span>
                      <strong>{transaction.note ?? "Yok"}</strong>
                    </article>
                  </div>
                </section>
              ) : null}

              {isEditing ? (
                <div className="transaction-editor">
                  <label className="compose-form__label" htmlFor={`transaction-account-${transaction.id}`}>
                    Hesap
                  </label>
                  <select
                    id={`transaction-account-${transaction.id}`}
                    className="compose-form__input"
                    value={editForm.account_id}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        account_id: event.target.value
                      }))
                    }
                  >
                    {accounts.map((nextAccount) => (
                      <option key={nextAccount.id} value={nextAccount.id}>
                        {nextAccount.name}
                      </option>
                    ))}
                  </select>

                  <label className="compose-form__label" htmlFor={`transaction-category-${transaction.id}`}>
                    Kategori
                  </label>
                  <input
                    id={`transaction-category-${transaction.id}`}
                    className="compose-form__input"
                    value={editForm.category_name}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        category_name: event.target.value
                      }))
                    }
                  />

                  <label className="compose-form__label" htmlFor={`transaction-type-${transaction.id}`}>
                    Tur
                  </label>
                  <select
                    id={`transaction-type-${transaction.id}`}
                    className="compose-form__input"
                    value={editForm.type}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        type: event.target.value
                      }))
                    }
                  >
                    <option value="expense">Harcama</option>
                    <option value="income">Gelir</option>
                    <option value="payment">Odeme</option>
                  </select>

                  <label className="compose-form__label" htmlFor={`transaction-amount-${transaction.id}`}>
                    Tutar
                  </label>
                  <input
                    id={`transaction-amount-${transaction.id}`}
                    className="compose-form__input"
                    inputMode="decimal"
                    value={editForm.amount}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        amount: event.target.value
                      }))
                    }
                  />

                  <label className="compose-form__label" htmlFor={`transaction-description-${transaction.id}`}>
                    Aciklama
                  </label>
                  <input
                    id={`transaction-description-${transaction.id}`}
                    className="compose-form__input"
                    value={editForm.description}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        description: event.target.value
                      }))
                    }
                  />

                  <label className="compose-form__label" htmlFor={`transaction-note-${transaction.id}`}>
                    Not
                  </label>
                  <input
                    id={`transaction-note-${transaction.id}`}
                    className="compose-form__input"
                    value={editForm.note}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        note: event.target.value
                      }))
                    }
                  />

                  <label className="compose-form__label" htmlFor={`transaction-date-${transaction.id}`}>
                    Zaman
                  </label>
                  <input
                    id={`transaction-date-${transaction.id}`}
                    className="compose-form__input"
                    type="datetime-local"
                    value={editForm.occurred_at}
                    onChange={(event) =>
                      setEditForm((current) => ({
                        ...current,
                        occurred_at: event.target.value
                      }))
                    }
                  />

                  <div className="event-actions">
                    <button
                      className="secondary-button"
                      type="button"
                      onClick={() => handleSave(transaction.id)}
                    >
                      Kaydet
                    </button>
                    <button className="ghost-button" type="button" onClick={cancelEditing}>
                      Vazgec
                    </button>
                  </div>
                </div>
              ) : null}

              {!isEditing ? (
                <div className="transaction-card__actions">
                  <button
                    className="ghost-button"
                    type="button"
                    onClick={() =>
                      setDetailId((current) => (current === transaction.id ? null : transaction.id))
                    }
                  >
                    {isShowingDetail ? "Detayi Gizle" : "Detay"}
                  </button>
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={() => startEditing(transaction)}
                  >
                    Duzenle
                  </button>
                  <button
                    className="ghost-button ghost-button--danger"
                    type="button"
                    onClick={() => handleDelete(transaction.id)}
                  >
                    Sil
                  </button>
                </div>
              ) : null}
            </article>
          );
        })}

        {!loading && !filteredTransactions.length ? (
          <article className="history-empty-state">
            <span className="status-card__eyebrow">Bos Gorunum</span>
            <strong>Bu filtrelerle islem bulunamadi</strong>
            <p>Donem, kategori veya tarih araligini genisletip tekrar bakabilirsin.</p>
          </article>
        ) : null}
      </section>
    </main>
  );
}
