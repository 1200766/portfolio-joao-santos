export type WeekDetails = {
  contest: string;
  drawDate: string;
  displayDate: string;
  closesAt: string;
};

function lisbonParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Lisbon",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);

  const read = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);

  return { year: read("year"), month: read("month"), day: read("day"), hour: read("hour") };
}

function isoWeekDetails(date: Date) {
  const thursday = new Date(date);
  const day = thursday.getUTCDay() || 7;
  thursday.setUTCDate(thursday.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 1));
  return {
    week: Math.ceil(
      ((thursday.getTime() - yearStart.getTime()) / 86400000 + 1) / 7,
    ),
    weekYear: thursday.getUTCFullYear(),
  };
}

function lisbonInstant(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute = 0,
) {
  const target = Date.UTC(year, month - 1, day, hour, minute);
  let guess = target;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Europe/Lisbon",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date(guess));
    const read = (type: Intl.DateTimeFormatPartTypes) =>
      Number(parts.find((part) => part.type === type)?.value ?? 0);
    const represented = Date.UTC(
      read("year"),
      read("month") - 1,
      read("day"),
      read("hour"),
      read("minute"),
    );
    guess += target - represented;
  }

  return new Date(guess).toISOString();
}

export function currentWeekDetails(now = new Date()): WeekDetails {
  const local = lisbonParts(now);
  const localDate = new Date(Date.UTC(local.year, local.month - 1, local.day));
  const weekday = localDate.getUTCDay();
  let daysUntilFriday = (5 - weekday + 7) % 7;
  if (daysUntilFriday === 0 && local.hour >= 19) daysUntilFriday = 7;
  localDate.setUTCDate(localDate.getUTCDate() + daysUntilFriday);

  const year = localDate.getUTCFullYear();
  const month = String(localDate.getUTCMonth() + 1).padStart(2, "0");
  const day = String(localDate.getUTCDate()).padStart(2, "0");
  const drawDate = `${year}-${month}-${day}`;
  const iso = isoWeekDetails(localDate);
  const week = String(iso.week).padStart(2, "0");

  return {
    contest: `S50-${iso.weekYear}-W${week}`,
    drawDate,
    displayDate: `${day}/${month}/${year}`,
    closesAt: lisbonInstant(year, Number(month), Number(day), 19),
  };
}
