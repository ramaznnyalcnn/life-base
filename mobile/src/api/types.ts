export type AccountType = "bank" | "cash" | "credit_card";
export type TransactionType = "expense" | "income" | "payment";

export type User = {
  id: number;
  email: string;
  display_name: string;
  is_active: boolean;
  is_admin: boolean;
};

export type HealthPayload = {
  status: string;
  mode?: {
    single_user?: boolean;
    locale?: string;
  };
  notifications?: {
    web_push?: boolean;
    vapid_configured?: boolean;
  };
  security?: {
    app_token_enabled?: boolean;
  };
  ai?: {
    provider?: string;
    model?: string;
    configured?: boolean;
  };
};

export type AuthSessionRead = {
  access_token: string;
  token_type: string;
  user: User;
};

export type Account = {
  id: number;
  name: string;
  type: AccountType;
  currency: string;
  balance: string | number;
  credit_limit: string | number | null;
  statement_day: number | null;
  due_day: number | null;
  issuer: string | null;
  is_active: boolean;
  available_credit?: string | number | null;
  used_credit?: string | number | null;
  utilization_ratio?: string | number | null;
};

export type Transaction = {
  id: number;
  account_id: number;
  category_id: number | null;
  category_name: string | null;
  type: TransactionType;
  amount: string | number;
  description: string;
  note: string | null;
  occurred_at: string;
  statement_month: string | null;
};

export type TransactionSummary = {
  period: "week" | "month" | "all";
  period_start: string | null;
  period_end: string | null;
  total_income: string | number;
  total_expense: string | number;
  total_payments: string | number;
  net_flow: string | number;
  transaction_count: number;
};

export type WalletSummary = {
  liquid_balance: string | number;
  total_card_available: string | number;
  total_card_used: string | number;
  total_credit_limit: string | number;
  net_worth: string | number;
  previous_month_net: string | number;
  previous_year_net: string | number;
  active_account_count: number;
  active_card_count: number;
  weekly_flow: TransactionSummary;
  monthly_flow: TransactionSummary;
  accounts: Account[];
};

export type CardStatementSummary = {
  account_id: number;
  account_name: string;
  issuer: string | null;
  statement_month: string;
  period_start: string;
  period_end: string;
  due_date: string | null;
  auto_resets_at: string;
  statement_amount: string | number;
  payment_activity: string | number;
  transaction_count: number;
};

export type Reminder = {
  id: number;
  event_id: number;
  remind_at: string;
  channel: string;
  is_sent: boolean;
};

export type EventItem = {
  id: number;
  title: string;
  description: string | null;
  starts_at: string;
  ends_at: string | null;
  is_all_day: boolean;
  is_important: boolean;
  is_completed: boolean;
  is_recurring: boolean;
  recurring_rule_id: number | null;
  reminders: Reminder[];
};

export type CalendarReminderItem = {
  id: number;
  event_id: number;
  event_title: string;
  remind_at: string;
  is_sent: boolean;
};

export type CalendarDashboard = {
  focus_event: EventItem | null;
  upcoming_events: EventItem[];
  past_events: EventItem[];
  pending_reminders: CalendarReminderItem[];
};

export type Medication = {
  id: number;
  name: string;
  dosage: string;
  instructions: string | null;
  weekdays: number[];
  dose_times: string[];
  starts_on: string;
  ends_on: string | null;
  timezone: string;
  is_active: boolean;
  device_id: string | null;
};

export type MedicationDoseStatus = "pending" | "taken" | "snoozed";

export type MedicationDoseItem = {
  medication_id: number;
  medication_name: string;
  dosage: string;
  instructions: string | null;
  scheduled_for: string;
  notify_at: string;
  status: MedicationDoseStatus;
  taken_at: string | null;
  snoozed_until: string | null;
};

export type MedicationDashboard = {
  medications: Medication[];
  today_doses: MedicationDoseItem[];
  upcoming_doses: MedicationDoseItem[];
};

export type RecurringEvent = {
  id: number;
  title: string;
  description: string | null;
  weekdays: number[];
  starts_on: string;
  ends_on: string | null;
  start_time: string | null;
  end_time: string | null;
  is_all_day: boolean;
  is_important: boolean;
  is_active: boolean;
  interval_weeks: number;
  device_id: string | null;
};

export type AIExecutionResponse = {
  status: "completed" | "needs_input" | "unsupported";
  assistant_message: string;
  missing_fields: string[];
  follow_up_question: string | null;
  transaction_id: number | null;
  transfer_id: number | null;
  event_id: number | null;
  recurring_event_id: number | null;
};
