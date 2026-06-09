type SearchableStationFields = {
  name: string;
  tags: string;
};

export function buildSearchKeywords(input: string): string[] {
  const spaced = input.replace(/([^\d.\s])(\d)/g, "$1 $2");
  return spaced
    .trim()
    .split(/\s+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function decimalFrequency(keyword: string): string | null {
  if (!/^\d{3,4}$/.test(keyword)) return null;
  return `${keyword.slice(0, -1)}.${keyword.slice(-1)}`;
}

export function stationMatchesKeywords(
  station: SearchableStationFields,
  keywords: string[]
): boolean {
  const haystack = `${station.name} ${station.tags}`.toLowerCase();

  return keywords.every((keyword) => {
    const normalized = keyword.toLowerCase();
    if (haystack.includes(normalized)) return true;

    const frequency = decimalFrequency(normalized);
    return frequency !== null && haystack.includes(frequency);
  });
}
