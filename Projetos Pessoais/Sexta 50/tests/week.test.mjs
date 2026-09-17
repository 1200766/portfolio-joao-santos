import assert from "node:assert/strict";
import test from "node:test";
import { currentWeekDetails } from "../lib/week.ts";

test("keeps the current Friday until 19:00 in summer Lisbon time", () => {
  const beforeClose = currentWeekDetails(
    new Date("2026-07-24T17:59:59.000Z"),
  );
  assert.deepEqual(beforeClose, {
    contest: "S50-2026-W30",
    drawDate: "2026-07-24",
    displayDate: "24/07/2026",
    closesAt: "2026-07-24T18:00:00.000Z",
  });

  const afterClose = currentWeekDetails(
    new Date("2026-07-24T18:00:00.000Z"),
  );
  assert.deepEqual(afterClose, {
    contest: "S50-2026-W31",
    drawDate: "2026-07-31",
    displayDate: "31/07/2026",
    closesAt: "2026-07-31T18:00:00.000Z",
  });
});

test("uses the winter Lisbon offset for the closing instant", () => {
  const beforeClose = currentWeekDetails(
    new Date("2026-12-18T18:59:59.000Z"),
  );
  assert.equal(beforeClose.drawDate, "2026-12-18");
  assert.equal(beforeClose.closesAt, "2026-12-18T19:00:00.000Z");

  const afterClose = currentWeekDetails(
    new Date("2026-12-18T19:00:00.000Z"),
  );
  assert.equal(afterClose.drawDate, "2026-12-25");
  assert.equal(afterClose.closesAt, "2026-12-25T19:00:00.000Z");
});

test("uses the ISO week-year at the turn of the year", () => {
  const newYearsDay = currentWeekDetails(
    new Date("2027-01-01T18:00:00.000Z"),
  );
  assert.equal(newYearsDay.drawDate, "2027-01-01");
  assert.equal(newYearsDay.contest, "S50-2026-W53");

  const afterYearEndClose = currentWeekDetails(
    new Date("2027-12-31T19:00:00.000Z"),
  );
  assert.equal(afterYearEndClose.drawDate, "2028-01-07");
  assert.equal(afterYearEndClose.contest, "S50-2028-W01");
});
