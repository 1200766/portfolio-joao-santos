export const EUROMILLIONS_RESULTS_URL =
  "https://www.jogossantacasa.pt/web/SCCartazResult/euroMilhoes";

export type OfficialEuromillionsResult = {
  contest: string;
  date: string;
  drawDate: string;
  drawOrder: number[];
  sourceUrl: string;
};

type FridayContestOption = {
  value: string;
  label: string;
};

function cleanHtml(value: string) {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&ordm;/gi, "º")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function toIsoDate(value: string) {
  const [day, month, year] = value.split("/");
  return `${year}-${month}-${day}`;
}

function validDrawOrder(numbers: number[]) {
  return (
    numbers.length === 5 &&
    new Set(numbers).size === 5 &&
    numbers.every((number) => Number.isInteger(number) && number >= 1 && number <= 50)
  );
}

async function readLatin1(response: Response) {
  return new TextDecoder("windows-1252").decode(await response.arrayBuffer());
}

async function officialFetch(
  input: string,
  init: RequestInit = {},
) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8_000);

  try {
    return await fetch(input, {
      ...init,
      cache: "no-store",
      signal: controller.signal,
      headers: {
        "User-Agent": "Sexta50/1.0 (+resultado-oficial)",
        ...init.headers,
      },
    });
  } finally {
    clearTimeout(timeout);
  }
}

export function parseFridayContestOptions(html: string) {
  const options: FridayContestOption[] = [];

  for (const match of html.matchAll(
    /<option[^>]*value=["']([\d.]+)["'][^>]*>([\s\S]*?)<\/option>/gi,
  )) {
    const label = cleanHtml(match[2]);
    if (/sexta-feira/i.test(label)) {
      options.push({ value: match[1], label });
    }
  }

  return options;
}

export function parseOfficialResultHtml(
  html: string,
): OfficialEuromillionsResult {
  const contest = html.match(
    /Sorteio:\s*([\d/]+)\s*-\s*sexta-feira/i,
  )?.[1];
  const date = html.match(
    /Data do Sorteio\s*-\s*(\d{2}\/\d{2}\/\d{4})/i,
  )?.[1];
  const orderBlock = html.match(
    /<div[^>]*class=["'][^"']*\bbetMiddle\b[^"']*\btwocol\b[^"']*\bregPad\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
  )?.[1];
  const listItems = orderBlock
    ? [...orderBlock.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi)]
    : [];
  const drawOrderText = listItems[1]
    ? cleanHtml(listItems[1][1]).split("+")[0]
    : "";
  const drawOrder = drawOrderText.match(/\d+/g)?.map(Number) ?? [];

  if (!contest || !date || !validDrawOrder(drawOrder)) {
    throw new Error("O formato do resultado oficial mudou.");
  }

  return {
    contest,
    date,
    drawDate: toIsoDate(date),
    drawOrder,
    sourceUrl: EUROMILLIONS_RESULTS_URL,
  };
}

async function fetchContestResult(value: string) {
  const response = await officialFetch(EUROMILLIONS_RESULTS_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ selectContest: value }).toString(),
  });
  if (!response.ok) {
    throw new Error("O detalhe do sorteio oficial não respondeu.");
  }

  return parseOfficialResultHtml(await readLatin1(response));
}

async function fridayOptions() {
  const response = await officialFetch(EUROMILLIONS_RESULTS_URL);
  if (!response.ok) throw new Error("A fonte oficial não respondeu.");

  const options = parseFridayContestOptions(await readLatin1(response));
  if (!options.length) {
    throw new Error("Não foi encontrado um sorteio de sexta-feira.");
  }

  return options;
}

export async function fetchLatestFridayResult() {
  const [latest] = await fridayOptions();
  return fetchContestResult(latest.value);
}

export async function fetchFridayResultForDate(targetDrawDate: string) {
  const options = await fridayOptions();

  for (const option of options.slice(0, 30)) {
    const result = await fetchContestResult(option.value);
    if (result.drawDate === targetDrawDate) return result;
    if (result.drawDate < targetDrawDate) return null;
  }

  return null;
}
