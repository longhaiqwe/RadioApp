export type LyricSnippet = {
  text: string;
  start?: number;
  end?: number;
  confidenceScore: number;
};

export type LyricsTranscriptionSegment = {
  id?: number;
  start?: number;
  end?: number;
  text: string;
  confidence?: number;
};

export type LyricsTranscription = {
  text: string;
  segments: LyricsTranscriptionSegment[];
};

export type SongCandidateSource = "netease" | "qq";

export type SongCandidate = {
  id: string;
  title: string;
  artist: string;
  album?: string;
  artworkUrl?: string;
  releaseDate?: string;
  source: SongCandidateSource;
  url: string;
  matchedSnippet?: string;
  confidenceScore?: number;
  metadataScore?: number;
  popularityScore?: number;
};

export type SyncedLyricLine = {
  id: string;
  time: number;
  text: string;
};

export type SyncedLyrics = {
  source: "qq" | "netease";
  rawLrc: string;
  lines: SyncedLyricLine[];
  matchedCandidate?: SongCandidate;
  matchedSnippet?: string;
  confidenceScore?: number;
  estimatedOffsetSeconds?: number;
  matchedSnippetsCount?: number;
  platformSongIds?: {
    qq?: string;
    netease?: string;
  };
};

export type StreamTrackMetadata = {
  rawTitle: string;
  title?: string;
  artist?: string;
};

export type RecognizedSongVersion = {
  id: string;
  candidate: SongCandidate;
  lyrics: SyncedLyrics;
};

export type RecognitionRequest = {
  streamUrl: string;
  stationId?: string;
  stationName?: string;
  languageHint?: string;
};

export type RecognitionResult = {
  method: "lyrics_asr";
  transcript: string;
  snippets: LyricSnippet[];
  candidates: SongCandidate[];
  streamMetadata?: StreamTrackMetadata | null;
  versions?: RecognizedSongVersion[];
  lyrics?: SyncedLyrics | null;
};
