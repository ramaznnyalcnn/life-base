import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import CalendarPage from "./Calendar";

vi.mock("../api/events", () => ({
  fetchCalendarDashboard: vi.fn(),
  updateEvent: vi.fn(),
  deleteEvent: vi.fn()
}));

import { deleteEvent, fetchCalendarDashboard, updateEvent } from "../api/events";

function isoAt(offsetDays, hour = 9, minute = 0) {
  const date = new Date();
  date.setHours(hour, minute, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return date.toISOString();
}

function dayLabel(offsetDays) {
  const date = new Date();
  date.setHours(12, 0, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return new Intl.DateTimeFormat("tr-TR", {
    weekday: "long",
    day: "numeric",
    month: "long"
  }).format(date);
}

function monthButtonLabel(offsetDays, planCount) {
  return `${dayLabel(offsetDays)}, ${planCount ? `${planCount} plan` : "plan yok"}`;
}

describe("CalendarPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders monthly calendar and opens a daily plan section", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: 1,
          title: "Disci Randevusu",
          description: "Kontrol",
          starts_at: isoAt(0, 14, 30),
          ends_at: isoAt(0, 15, 30),
          is_important: false,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [
        {
          id: 2,
          title: "Dun Sporu",
          description: "Hafif tempo",
          starts_at: isoAt(-1, 18, 0),
          ends_at: isoAt(-1, 19, 0),
          is_important: true,
          is_completed: false,
          reminders: []
        }
      ],
      pending_reminders: [
        {
          id: 11,
          event_id: 1,
          event_title: "Disci Randevusu",
          remind_at: isoAt(0, 12, 30),
          is_sent: false
        }
      ]
    });

    const user = userEvent.setup();
    render(<CalendarPage />);

    expect(await screen.findByRole("heading", { name: new Intl.DateTimeFormat("tr-TR", {
      month: "long",
      year: "numeric"
    }).format(new Date()) })).toBeInTheDocument();
    expect(screen.getByText("1 Haftalik Program")).toBeInTheDocument();
    expect(screen.queryByText("Aylik Takvim")).not.toBeInTheDocument();
    expect(screen.queryByText("Secili Gunun Havasi")).not.toBeInTheDocument();

    expect(screen.getAllByText("Disci Randevusu").length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByRole("button", { name: "Tamamla" }).length).toBeGreaterThanOrEqual(1);
  });

  it("sends event update when marked complete", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: 1,
          title: "Toplanti",
          description: "Sunum",
          starts_at: isoAt(0, 14, 30),
          ends_at: isoAt(0, 15, 30),
          is_important: false,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [],
      pending_reminders: []
    });
    updateEvent.mockResolvedValue({});

    const user = userEvent.setup();
    render(<CalendarPage />);

    await screen.findByText("1 Haftalik Program");
    await user.click(screen.getAllByRole("button", { name: "Tamamla" })[0]);

    expect(updateEvent).toHaveBeenCalledWith(1, { is_completed: true });
    expect(fetchCalendarDashboard).toHaveBeenLastCalledWith(true);
  });

  it("updates the selected-day preview when a month day is clicked", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: 1,
          title: "Bugunku Plan",
          description: "Gunluk akis",
          starts_at: isoAt(0, 10, 0),
          ends_at: isoAt(0, 11, 0),
          is_important: false,
          is_completed: false,
          reminders: []
        },
        {
          id: 2,
          title: "Cuma Aksam Yemegi",
          description: "Arkadaslarla bulusma",
          starts_at: isoAt(3, 20, 0),
          ends_at: isoAt(3, 22, 0),
          is_important: true,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [],
      pending_reminders: []
    });

    const user = userEvent.setup();
    render(<CalendarPage />);

    expect(await screen.findByText("Secili Gunun Yapilacaklari")).toBeInTheDocument();
    expect(screen.getAllByText("Bugunku Plan").length).toBeGreaterThanOrEqual(1);

    await user.click(screen.getByRole("button", { name: monthButtonLabel(3, 1) }));

    expect(screen.getAllByRole("heading", { name: dayLabel(3) }).length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText("Cuma Aksam Yemegi").length).toBeGreaterThanOrEqual(1);
  });

  it("sends delete request and refreshes", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: 1,
          title: "Toplanti",
          description: "Sunum",
          starts_at: isoAt(0, 14, 30),
          ends_at: isoAt(0, 15, 30),
          is_important: false,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [],
      pending_reminders: []
    });
    deleteEvent.mockResolvedValue(null);

    const user = userEvent.setup();
    render(<CalendarPage />);

    await screen.findByText("1 Haftalik Program");
    await user.click(screen.getAllByRole("button", { name: "Sil" })[0]);

    expect(deleteEvent).toHaveBeenCalledWith(1);
    expect(fetchCalendarDashboard).toHaveBeenLastCalledWith(true);
  });

  it("shows all-day events without forcing an hour label", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: 1,
          title: "Spor Rutini",
          description: "Saatsiz aliskanlik",
          starts_at: isoAt(0, 0, 0),
          ends_at: null,
          is_all_day: true,
          is_important: false,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [],
      pending_reminders: []
    });

    render(<CalendarPage />);

    expect(await screen.findAllByText("Tum gun")).not.toHaveLength(0);
  });

  it("renders recurring routines without edit and delete actions", async () => {
    fetchCalendarDashboard.mockResolvedValue({
      focus_event: null,
      upcoming_events: [
        {
          id: -101,
          title: "Spor",
          description: "Haftalik rutin",
          starts_at: isoAt(0, 0, 0),
          ends_at: null,
          is_all_day: true,
          is_recurring: true,
          recurring_rule_id: 9,
          is_important: false,
          is_completed: false,
          reminders: []
        }
      ],
      past_events: [],
      pending_reminders: []
    });

    render(<CalendarPage />);

    expect(await screen.findAllByText("Haftalik rutin")).not.toHaveLength(0);
    expect(screen.getByText("Bu gorunum haftalik bir rutinden uretiliyor.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Duzenle" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Sil" })).not.toBeInTheDocument();
  });
});
