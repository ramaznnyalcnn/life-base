import { useEffect, useMemo, useRef, useState } from "react";

import { fetchAccounts } from "../api/accounts";
import {
  deleteTransaction,
  fetchTransactions,
  updateTransaction
} from "../api/transactions";

const EXPENSE_CATEGORIES = [
  "Market", "Yeme-İçme", "Kahve", "Fatura", "Abonelik",
  "Ulaşım", "Yakıt", "Sağlık", "Eczane", "Kira",
  "Eğlence", "Giyim", "Eğitim", "Elektronik",
  "Kişisel Bakım", "Spor", "Diğer"
];

const INCOME_CATEGORIES = [
  "Maaş", "Ek Gelir", "Serbest Çalışma", "Yatırım", "Prim", "Diğer Gelir"
];

const PAYMENT_CATEGORIES = [
  "Kredi Kartı Ödemesi", "Borç Ödemesi", "Diğer Ödeme"
];

function getCategoryList(type) {
  if (type === "income") return INCOME_CATEGORIES;
  if (type === "payment") return PAYMENT_CATEGORIES;
  return EXPENSE_CATEGORIES;
}

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

const ANALYSIS_SEGMENT_OPTIONS = [
  { id: "all", label: "Tum Zaman" },
  { id: "month", label: "Bu Ay" },
  { id: "quarter", label: "Son 90 Gun" },
  { id: "year", label: "Bu Yil" }
];

const ANALYSIS_WHEEL_GESTURE_DIVISOR = 420;
const ANALYSIS_TOUCH_GESTURE_DIVISOR = 240;

/* Odometer Hook for Premium Transitions */
function useOdometer(value, duration = 1200, resetKey = "") {
  const [displayValue, setDisplayValue] = useState(0);
  const startValue = useRef(0);
  const startTime = useRef(null);
  const frameId = useRef(null);
  const previousResetKey = useRef(resetKey);
  const currentValueRef = useRef(0);

  useEffect(() => {
    currentValueRef.current = displayValue;
  }, [displayValue]);

  useEffect(() => {
    const targetValue = Number(value) || 0;
    const shouldRestartFromZero = previousResetKey.current !== resetKey;
    const originValue = shouldRestartFromZero ? 0 : currentValueRef.current;

    previousResetKey.current = resetKey;
    startValue.current = originValue;
    setDisplayValue(originValue);

    if (import.meta.env.MODE === "test") {
      setDisplayValue(targetValue);
      return undefined;
    }

    startTime.current = performance.now();

    const animate = (time) => {
      const elapsed = time - startTime.current;
      const progress = Math.min(elapsed / duration, 1);

      const easeOutExpo = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
      const current = startValue.current + (targetValue - startValue.current) * easeOutExpo;

      setDisplayValue(current);

      if (progress < 1) {
        frameId.current = requestAnimationFrame(animate);
      } else {
        setDisplayValue(targetValue);
      }
    };

    frameId.current = requestAnimationFrame(animate);

    return () => cancelAnimationFrame(frameId.current);
  }, [duration, resetKey, value]);

  return displayValue;
}

function AnimatedMoney({ value, animationKey = "" }) {
  const animatedValue = useOdometer(Number(value) || 0, 1200, animationKey);
  return <>{formatMoney(animatedValue)}</>;
}

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

function buildSmoothPath(values, width, height, padding, maxValue) {
  if (!values.length) return "";
  if (values.length === 1) {
    const x = width / 2;
    const y = height - padding - (maxValue ? (values[0] / maxValue) * (height - padding * 2) : 0);
    return `M ${x} ${y}`;
  }

  const innerWidth = width - padding * 2;
  const innerHeight = height - padding * 2;
  const stepX = innerWidth / (values.length - 1);

  const points = values.map((val, index) => {
    const x = padding + index * stepX;
    const y = height - padding - (maxValue ? (val / maxValue) * innerHeight : 0);
    return { x, y };
  });

  return points.reduce((acc, point, index, array) => {
    if (index === 0) return `M ${point.x} ${point.y}`;

    // Simple cubic bezier: horizontal handles pointing halfway back/forward
    const prev = array[index - 1];
    const cpX1 = prev.x + (point.x - prev.x) / 2;
    const cpY1 = prev.y;
    const cpX2 = point.x - (point.x - prev.x) / 2;
    const cpY2 = point.y;

    return `${acc} C ${cpX1} ${cpY1}, ${cpX2} ${cpY2}, ${point.x} ${point.y}`;
  }, "");
}

function buildSmoothAreaPath(values, width, height, padding, maxValue) {
  if (!values.length) {
    return "";
  }

  const line = buildSmoothPath(values, width, height, padding, maxValue);
  const innerWidth = width - padding * 2;
  const lastX = padding + (values.length === 1 ? innerWidth / 2 : innerWidth);

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

  const width = 380;
  const height = 240;
  const padding = 24;
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
        <defs>
          <linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--wf-expense)" stopOpacity="0.3" />
            <stop offset="100%" stopColor="var(--wf-expense)" stopOpacity="0.0" />
          </linearGradient>
          <linearGradient id="lineIncomeGradient" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="var(--wf-income)" stopOpacity="0.6" />
            <stop offset="100%" stopColor="var(--wf-income)" stopOpacity="1" />
          </linearGradient>
          <linearGradient id="lineOutgoingGradient" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="var(--wf-expense)" stopOpacity="0.8" />
            <stop offset="100%" stopColor="var(--wf-expense)" stopOpacity="1" />
          </linearGradient>
          <filter id="neonGlowOutline" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        <rect x="0" y="0" width={width} height={height} fill="none" />

        {/* Neon Grid Lines */}
        {[0.25, 0.5, 0.75, 1].map((step) => {
          const y = height - padding - (height - padding * 2) * step;
          return <line key={step} x1={padding} x2={width - padding} y1={y} y2={y} className="history-trend-chart__grid" style={{ strokeDasharray: "4 4", opacity: 0.15 }} />;
        })}

        <path
          d={buildSmoothAreaPath(outgoingValues, width, height, padding, maxValue)}
          className="history-trend-chart__area"
          style={{ fill: "url(#areaGradient)" }}
        />
        <path
          d={buildSmoothPath(incomeValues, width, height, padding, maxValue)}
          className="history-trend-chart__line history-trend-chart__line--income"
          style={{ stroke: "url(#lineIncomeGradient)", filter: "url(#neonGlowOutline)" }}
        />
        <path
          d={buildSmoothPath(outgoingValues, width, height, padding, maxValue)}
          className="history-trend-chart__line history-trend-chart__line--outgoing"
          style={{ stroke: "url(#lineOutgoingGradient)", filter: "url(#neonGlowOutline)" }}
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

function ActivityRings({ categories, totalOutgoing, animationKey }) {
  const rings = categories.slice(0, 3).map((category, index) => {
    const share = totalOutgoing > 0 ? category.total / totalOutgoing : 0;
    const radius = 42 - index * 12; // 42, 30, 18
    const circumference = 2 * Math.PI * radius;
    // We animate dashoffset from circumference to the target dashoffset in CSS,
    // so we set custom properties here

    return {
      ...category,
      share,
      color: CHART_COLORS[index % CHART_COLORS.length],
      radius,
      circumference,
      dashoffset: Math.max(0, circumference * (1 - share))
    };
  });

  return (
    <div className="analysis-rings">
      <div className="analysis-rings__svg-wrapper">
        <svg viewBox="0 0 100 100" className="analysis-rings__svg">
          <defs>
            <filter id="ringGlow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>
          {rings.map((ring, i) => (
            <g key={ring.key} className="analysis-rings__group">
              <circle
                cx="50" cy="50" r={ring.radius}
                className="analysis-rings__track"
                style={{ stroke: ring.color }}
              />
              <circle
                cx="50" cy="50" r={ring.radius}
                className="analysis-rings__progress"
                style={{
                  stroke: ring.color,
                  strokeDasharray: ring.circumference,
                  strokeDashoffset: ring.circumference, // Starts empty
                  '--dash-target': ring.dashoffset,
                  animation: `drawRing 1.8s cubic-bezier(0.16, 1, 0.3, 1) ${i * 0.15}s forwards`,
                  filter: 'url(#ringGlow)'
                }}
              />
            </g>
          ))}
        </svg>
        <div className="analysis-rings__center">
          <span className="analysis-rings__center-label">Toplam</span>
          <strong className="analysis-rings__center-amount">
            <AnimatedMoney value={totalOutgoing} animationKey={animationKey} />
          </strong>
        </div>
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
  const [activeAppTab, setActiveAppTab] = useState("overview"); // "overview" | "history"
  const [showDetailedAnalysis, setShowDetailedAnalysis] = useState(false);
  const [analysisTransitionProgress, setAnalysisTransitionProgress] = useState(0);
  const analysisShellRef = useRef(null);
  const overviewScrollRef = useRef(null);
  const historyScrollRef = useRef(null);
  const analysisGestureProgressRef = useRef(0);
  const analysisTouchStartYRef = useRef(null);
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

  const calculateAnalysis = (txns) => {
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

    for (const transaction of txns) {
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
  };

  const allTimeTransactions = useMemo(() => {
    const fromDate = analysisFilters.dateFrom ? new Date(analysisFilters.dateFrom) : null;
    const toDate = analysisFilters.dateTo ? new Date(analysisFilters.dateTo) : null;
    const selectedCategory = analysisFilters.category.trim() ? analysisFilters.category.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") : "";

    return transactions.filter((transaction) => {
      const occurredAt = new Date(transaction.occurred_at);
      const transactionCategory = (transaction.category_name || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");

      if (fromDate && occurredAt < fromDate) return false;
      if (toDate && occurredAt > toDate) return false;
      if (selectedCategory && transactionCategory !== selectedCategory) return false;

      return true;
    });
  }, [analysisFilters.category, analysisFilters.dateFrom, analysisFilters.dateTo, transactions]);

  const currentMonthTransactions = useMemo(() => {
    const now = new Date();
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    return allTimeTransactions.filter(t => new Date(t.occurred_at) >= startOfCurrentMonth);
  }, [allTimeTransactions]);

  const comparisonTransactions = useMemo(() => {
    const now = new Date();
    const segmentStart = (() => {
      if (analysisFilters.segment === "month") return new Date(now.getFullYear(), now.getMonth(), 1);
      if (analysisFilters.segment === "quarter") {
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        d.setDate(d.getDate() - 90);
        return d;
      }
      if (analysisFilters.segment === "year") return new Date(now.getFullYear(), 0, 1);
      return null;
    })();

    return allTimeTransactions.filter(t => {
      if (segmentStart && new Date(t.occurred_at) < segmentStart) return false;
      return true;
    });
  }, [allTimeTransactions, analysisFilters.segment]);

  const thisMonthData = useMemo(() => calculateAnalysis(currentMonthTransactions), [currentMonthTransactions]);
  const comparisonData = useMemo(() => calculateAnalysis(comparisonTransactions), [comparisonTransactions]);

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

  useEffect(() => {
    analysisGestureProgressRef.current = analysisTransitionProgress;
  }, [analysisTransitionProgress]);

  useEffect(() => {
    const shellNode = analysisShellRef.current;

    if (!shellNode || loading) {
      return undefined;
    }

    function applyGestureDelta(rawDelta) {
      const next = Math.max(0, Math.min(1, analysisGestureProgressRef.current + rawDelta));
      analysisGestureProgressRef.current = next;
      setAnalysisTransitionProgress(next);
      setActiveAppTab(next >= 0.5 ? "history" : "overview");
    }

    function shouldAllowHistoryScroll(deltaY) {
      const detailNode = historyScrollRef.current;

      if (!detailNode || analysisGestureProgressRef.current < 0.98) {
        return false;
      }

      const atTop = detailNode.scrollTop <= 0;
      const atBottom = detailNode.scrollTop + detailNode.clientHeight >= detailNode.scrollHeight - 1;

      if (deltaY > 0) {
        return !atBottom;
      }

      if (deltaY < 0) {
        return !atTop;
      }

      return false;
    }

    function shouldAllowOverviewScroll(deltaY) {
      const overviewNode = overviewScrollRef.current;

      if (!overviewNode || analysisGestureProgressRef.current > 0.02) {
        return false;
      }

      const canScroll = overviewNode.scrollHeight > overviewNode.clientHeight + 1;

      if (!canScroll) {
        return false;
      }

      const atTop = overviewNode.scrollTop <= 0;
      const atBottom =
        overviewNode.scrollTop + overviewNode.clientHeight >= overviewNode.scrollHeight - 1;

      if (deltaY > 0) {
        return !atBottom;
      }

      if (deltaY < 0) {
        return !atTop;
      }

      return false;
    }

    function handleWheel(event) {
      if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) {
        return;
      }

      if (shouldAllowOverviewScroll(event.deltaY)) {
        return;
      }

      if (shouldAllowHistoryScroll(event.deltaY)) {
        return;
      }

      event.preventDefault();
      applyGestureDelta(event.deltaY / ANALYSIS_WHEEL_GESTURE_DIVISOR);
    }

    function handleTouchStart(event) {
      analysisTouchStartYRef.current = event.touches[0]?.clientY ?? null;
    }

    function handleTouchMove(event) {
      if (analysisTouchStartYRef.current == null) {
        return;
      }

      const currentY = event.touches[0]?.clientY ?? analysisTouchStartYRef.current;
      const deltaY = analysisTouchStartYRef.current - currentY;

      if (Math.abs(deltaY) < 2) {
        return;
      }

      if (shouldAllowOverviewScroll(deltaY)) {
        analysisTouchStartYRef.current = currentY;
        return;
      }

      if (shouldAllowHistoryScroll(deltaY)) {
        analysisTouchStartYRef.current = currentY;
        return;
      }

      event.preventDefault();
      applyGestureDelta(deltaY / ANALYSIS_TOUCH_GESTURE_DIVISOR);
      analysisTouchStartYRef.current = currentY;
    }

    function handleTouchEnd() {
      analysisTouchStartYRef.current = null;
    }

    shellNode.addEventListener("wheel", handleWheel, { passive: false });
    shellNode.addEventListener("touchstart", handleTouchStart, { passive: true });
    shellNode.addEventListener("touchmove", handleTouchMove, { passive: false });
    shellNode.addEventListener("touchend", handleTouchEnd, { passive: true });

    return () => {
      shellNode.removeEventListener("wheel", handleWheel);
      shellNode.removeEventListener("touchstart", handleTouchStart);
      shellNode.removeEventListener("touchmove", handleTouchMove);
      shellNode.removeEventListener("touchend", handleTouchEnd);
    };
  }, [loading]);

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

  const timelineGroups = useMemo(() => {
    const groups = new Map();
    for (const transaction of comparisonTransactions) {
      const dateLabel = new Intl.DateTimeFormat("tr-TR", { 
        day: "numeric", month: "long", year: "numeric", weekday: "long" 
      }).format(new Date(transaction.occurred_at));
      
      if (!groups.has(dateLabel)) {
        groups.set(dateLabel, []);
      }
      groups.get(dateLabel).push(transaction);
    }
    return Array.from(groups.entries());
  }, [comparisonTransactions]);

  const selectedAnalysisSegment =
    ANALYSIS_SEGMENT_OPTIONS.find((segment) => segment.id === analysisFilters.segment)?.label ??
    ANALYSIS_SEGMENT_OPTIONS[0].label;
  const analysisCounterAnimationKey = [
    activeAppTab,
    analysisFilters.segment,
    analysisFilters.category || "all",
    analysisFilters.dateFrom || "start",
    analysisFilters.dateTo || "end",
    thisMonthData.analysis.net,
    thisMonthData.analysis.totalIncome,
    thisMonthData.analysis.totalOutgoing,
    thisMonthData.analysis.totalPayments
  ].join("|");
  const analysisOverviewZoomProgress = Math.min(1, analysisTransitionProgress / 0.54);
  const analysisViewSwapProgress = Math.max(0, Math.min(1, (analysisTransitionProgress - 0.34) / 0.3));
  const analysisDetailGrowProgress = Math.max(0, Math.min(1, (analysisTransitionProgress - 0.46) / 0.54));
  const analysisOverviewSceneStyle = {
    transform: `perspective(1200px) translateY(${analysisOverviewZoomProgress * -20}px) scale(${1 + analysisOverviewZoomProgress * 0.18}) rotateX(${analysisOverviewZoomProgress * -8}deg)`,
    opacity: Math.max(0, 1 - analysisViewSwapProgress * 1.2),
    filter: `saturate(${1 - analysisViewSwapProgress * 0.18}) blur(${analysisViewSwapProgress * 5}px)`,
    pointerEvents: analysisTransitionProgress < 0.5 ? "auto" : "none"
  };
  const analysisDetailSceneStyle = {
    opacity: Math.max(0, (analysisTransitionProgress - 0.28) / 0.5),
    transformOrigin: "50% 18%",
    transform: `perspective(1200px) translateY(${-28 + analysisDetailGrowProgress * 28}px) scale(${1.52 - analysisDetailGrowProgress * 0.52}) rotateX(${12 - analysisDetailGrowProgress * 12}deg)`,
    filter: `blur(${(1 - analysisDetailGrowProgress) * 7}px)`,
    pointerEvents: analysisTransitionProgress > 0.52 ? "auto" : "none"
  };
  const analysisGlowStyle = {
    transform: `scale(${1 + analysisTransitionProgress * 0.08})`,
    opacity: Math.sin(analysisTransitionProgress * Math.PI) * 0.5
  };
  const analysisCueStyle = {
    opacity: Math.max(0, 1 - analysisTransitionProgress * 1.8),
    transform: `translateY(${analysisTransitionProgress * 10}px)`
  };
  const activityRingsCard = (
    <article className="history-chart-card" style={{ marginTop: "16px" }}>
      <ActivityRings
        categories={thisMonthData.donutCategories}
        totalOutgoing={thisMonthData.analysis.totalOutgoing}
        animationKey={analysisCounterAnimationKey}
      />
    </article>
  );
  const detailedAnalysisSection = (
    <div className="analysis-detailed-content">
      <div className="history-analysis-toolbar">
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

      <section className="history-analysis-grid" style={{ marginTop: "24px" }}>
        <div style={{ padding: "0 20px", marginBottom: "16px" }}>
          <p className="status-card__eyebrow" style={{ marginBottom: "8px" }}>Gecmisle Kiyasla</p>
          <div className="history-segmented-control" role="tablist" aria-label="Analiz zaman carki">
            {ANALYSIS_SEGMENT_OPTIONS.map((segment) => (
              <button
                key={segment.id}
                className={`history-segmented-control__btn ${analysisFilters.segment === segment.id ? "active" : ""}`}
                type="button"
                onClick={() => handleAnalysisFilterChange("segment", segment.id)}
              >
                {segment.label}
              </button>
            ))}
          </div>
        </div>

        <article className="history-chart-card">
          <div className="history-chart-card__header">
            <div>
              <p className="status-card__eyebrow">Aylik Akis</p>
              <h2>Gelir ve gider trendi</h2>
            </div>
            <span className="history-summary-pill history-summary-pill--soft">
              Son {comparisonData.trendMonths.length || 0} ay
            </span>
          </div>
          <TrendChart months={comparisonData.trendMonths} />
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
                <strong>%{comparisonData.analysis.fixedRatio.toFixed(0)}</strong>
              </div>
              <div className="history-progress">
                <span style={{ width: `${Math.min(comparisonData.analysis.fixedRatio, 100)}%` }} />
              </div>
              <p>{formatMoney(comparisonData.analysis.fixedOutgoing)}</p>
            </article>

            <article className="history-split-bar-card">
              <div className="history-split-bar-card__head">
                <span>Degisken giderler</span>
                <strong>%{comparisonData.analysis.variableRatio.toFixed(0)}</strong>
              </div>
              <div className="history-progress history-progress--variable">
                <span style={{ width: `${Math.min(comparisonData.analysis.variableRatio, 100)}%` }} />
              </div>
              <p>{formatMoney(comparisonData.analysis.variableOutgoing)}</p>
            </article>
          </div>

          <div className="history-insight-grid history-insight-grid--analysis">
            <article className="history-insight-card">
              <span>En Zor Ay</span>
              <strong>
                {comparisonData.analysis.worstMonth
                  ? `${comparisonData.analysis.worstMonth.label} · ${formatMoney(comparisonData.analysis.worstMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-insight-card">
              <span>En Rahat Ay</span>
              <strong>
                {comparisonData.analysis.bestMonth
                  ? `${comparisonData.analysis.bestMonth.label} · ${formatMoney(comparisonData.analysis.bestMonth.net)}`
                  : "Veri yok"}
              </strong>
            </article>
            <article className="history-insight-card">
              <span>En Degisken Kategori</span>
              <strong>{comparisonData.analysis.volatileCategory?.label ?? "Veri yok"}</strong>
            </article>
            <article className="history-insight-card">
              <span>En Buyuk Harcama</span>
              <strong>
                {comparisonData.analysis.largestExpense
                  ? `${comparisonData.analysis.largestExpense.description} · ${formatMoney(comparisonData.analysis.largestExpense.amount)}`
                  : "Harcama yok"}
              </strong>
            </article>
          </div>
        </article>
      </section>
    </div>
  );
  const historyLayerContent = (
    <>
      <div className="analysis-search-wrapper">
        <div className="analysis-search-bar">
          <svg className="analysis-search-bar__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input
            type="text"
            className="analysis-search-bar__input"
            placeholder="Kira, kahve, maas..."
            value={filters.search}
            onChange={(e) => {
              handleFilterChange("search", e.target.value);
            }}
            onKeyDown={(e) => e.key === "Enter" && applyFilters(e)}
          />
          <button
            type="button"
            className={`analysis-search-bar__filter-btn ${filters.type || filters.accountId ? "active" : ""}`}
            onClick={() => setSearchOpen((open) => !open)}
          >
            Filtre{filters.type || filters.accountId ? " •" : ""}
          </button>
        </div>

        {searchOpen && (
          <form className="analysis-search-drawer" onSubmit={applyFilters}>
            <div className="analysis-search-drawer__grid">
              <div className="analysis-search-drawer__field">
                <label>Hesap</label>
                <select
                  value={filters.accountId}
                  onChange={(event) => handleFilterChange("accountId", event.target.value)}
                >
                  <option value="">Tum hesaplar</option>
                  {accounts.map((account) => (
                    <option key={account.id} value={account.id}>{account.name}</option>
                  ))}
                </select>
              </div>
              <div className="analysis-search-drawer__field">
                <label>Tur</label>
                <select
                  value={filters.type}
                  onChange={(event) => handleFilterChange("type", event.target.value)}
                >
                  <option value="">Tum hareketler</option>
                  <option value="expense">Harcama</option>
                  <option value="income">Gelir</option>
                  <option value="payment">Odeme</option>
                </select>
              </div>
            </div>
            <button className="primary-button" type="submit">Filtreyi Uygula</button>
          </form>
        )}
      </div>

      <section className="analysis-timeline">
        {timelineGroups.map(([dateLabel, groupTransactions]) => (
          <div className="analysis-timeline__group" key={dateLabel}>
            <div className="analysis-timeline__header">
              <div className="analysis-timeline__bullet"></div>
              <span>{dateLabel}</span>
            </div>
            <div className="analysis-timeline__items">
              {groupTransactions.map((transaction) => {
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
                        <select
                          id={`transaction-category-${transaction.id}`}
                          className="compose-form__input"
                          value={editForm.category_name}
                          onChange={(event) =>
                            setEditForm((current) => ({
                              ...current,
                              category_name: event.target.value
                            }))
                          }
                        >
                          <option value="">Seç...</option>
                          {getCategoryList(editForm.type).map((cat) => (
                            <option key={cat} value={cat}>{cat}</option>
                          ))}
                        </select>

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
            </div>
          </div>
        ))}

        {!loading && !comparisonTransactions.length ? (
          <article className="history-empty-state">
            <span className="status-card__eyebrow">Bos Gorunum</span>
            <strong>Bu filtrelerle islem bulunamadi</strong>
            <p>Donem, kategori veya tarih araligini genisletip tekrar bakabilirsin.</p>
          </article>
        ) : null}
      </section>

      <section className="analysis-collapsible-section">
        <button
          className="secondary-button analysis-collapsible-toggle"
          type="button"
          aria-expanded={showDetailedAnalysis}
          onClick={() => setShowDetailedAnalysis((current) => !current)}
        >
          {showDetailedAnalysis ? "Grafikleri Gizle" : "Detayli Analiz & Grafikleri Goster"}
          <span
            className="analysis-collapsible-toggle__chevron"
            aria-hidden="true"
            style={{ transform: showDetailedAnalysis ? "rotate(180deg)" : "rotate(0deg)" }}
          >
            ▼
          </span>
        </button>

        {showDetailedAnalysis ? (
          <div className="analysis-collapsible-content slide-in-top" style={{ marginTop: "24px" }}>
            {detailedAnalysisSection}
          </div>
        ) : null}
      </section>
    </>
  );

  return (
    <main className="shell">
      {loading && !comparisonTransactions.length ? (
        <section className="account-list">
          <article className="account-card">Yukleniyor...</article>
        </section>
      ) : (
        <div className="history-tab-overview slide-in-bottom" data-scene={activeAppTab}>
          <div className="analysis-scroll-shell" ref={analysisShellRef}>
            <div className="analysis-scroll-stage">
              <div className="analysis-scroll-stage__glow" aria-hidden="true" style={analysisGlowStyle} />

              <section
                className="analysis-scroll-layer analysis-scroll-layer--overview"
                style={analysisOverviewSceneStyle}
              >
                <div className="analysis-overview-shell" ref={overviewScrollRef}>
                  <section className="accounts-panel history-hero-panel">
                    <div className="history-hero-layout" style={{ marginTop: "12px" }}>
                      <div className="history-hero-main">
                        <article className="analysis-odometer-card">
                          <span className="analysis-odometer-card__label">Toplam Net Durum</span>
                          <strong className="analysis-odometer-card__amount">
                            <AnimatedMoney value={thisMonthData.analysis.net} animationKey={analysisCounterAnimationKey} />
                          </strong>
                          <div className="analysis-odometer-card__meta">
                            <span className="analysis-odometer-card__income">
                              Gelir <AnimatedMoney value={thisMonthData.analysis.totalIncome} animationKey={analysisCounterAnimationKey} />
                            </span>
                            <span className="analysis-odometer-card__separator">·</span>
                            <span className="analysis-odometer-card__outgoing">
                              Gider <AnimatedMoney value={thisMonthData.analysis.totalOutgoing} animationKey={analysisCounterAnimationKey} />
                            </span>
                          </div>
                          {thisMonthData.analysis.totalPayments > 0 ? (
                            <p className="analysis-odometer-card__note">
                              Kart odemeleri yansitilmiyor: <AnimatedMoney value={thisMonthData.analysis.totalPayments} animationKey={analysisCounterAnimationKey} />
                            </p>
                          ) : null}
                        </article>
                        {activityRingsCard}
                      </div>
                      <div className="history-hero-grid">
                        <article className="history-metric-card">
                          <span>Aylik Degisim</span>
                          <strong>{formatPercent(thisMonthData.analysis.monthlyChange)}</strong>
                          <p>Onceki aya kiyasla</p>
                        </article>

                        <article className="history-metric-card">
                          <span>Tasarruf Orani</span>
                          <strong>%{thisMonthData.analysis.savingsRate.toFixed(0)}</strong>
                          <p>Kalan paranin orani</p>
                        </article>

                        <article className="history-metric-card">
                          <span>Top Kategori</span>
                          <strong>{thisMonthData.analysis.topCategory?.label ?? "Veri yok"}</strong>
                          <p>
                            {thisMonthData.analysis.topCategory
                              ? formatMoney(thisMonthData.analysis.topCategory.total)
                              : "Harcama yok"}
                          </p>
                        </article>

                        <article className="history-metric-card">
                          <span>Islem Basina</span>
                          <strong>{formatMoney(thisMonthData.analysis.averageExpense)}</strong>
                          <p>Tekil harcama ucreti</p>
                        </article>
                      </div>
                    </div>
                  </section>

                  <section className="analysis-stories-section">
                    <div className="accounts-panel__header" style={{ padding: "0 20px" }}>
                      <div>
                        <p className="status-card__eyebrow">Zeka Onerileri</p>
                        <p className="accounts-panel__meta">Finansal sinyallerin</p>
                      </div>
                    </div>

                    <div className="analysis-story-list">
                      {comparisonData.recommendations.map((recommendation, index) => {
                        const types = ["warning", "success", "info", "danger"];
                        const tone = types[Math.min(index, types.length - 1)];

                        return (
                          <article className={`analysis-story-card analysis-story-card--${tone}`} key={recommendation}>
                            <div className="analysis-story-card__icon">
                              {tone === "warning" ? "💡" : tone === "danger" ? "🚨" : tone === "success" ? "🚀" : "✨"}
                            </div>
                            <p>{recommendation}</p>
                          </article>
                        );
                      })}
                    </div>
                  </section>
                </div>
              </section>

              <section className="analysis-scroll-layer analysis-scroll-layer--detail" style={analysisDetailSceneStyle}>
                <div className="analysis-detail-shell" ref={historyScrollRef}>
                  {historyLayerContent}
                </div>
              </section>
            </div>
          </div>
        </div>
      )}

      {error ? <p className="error-banner">{error}</p> : null}
    </main>
  );
}
