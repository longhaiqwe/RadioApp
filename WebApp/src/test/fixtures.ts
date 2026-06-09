import type { Station } from "@/features/stations/stationTypes";

export const stationFixture: Station = {
  changeuuid: "change-1",
  stationuuid: "station-1",
  id: "station-1",
  name: "清晨音乐台",
  url: "http://lhttp.qingting.fm/live/4915/64k.mp3",
  urlResolved: "http://lhttp.qingting.fm/live/4915/64k.mp3",
  homepage: "https://m.weibo.cn/u/2022851417",
  favicon: "",
  tags: "music,pop music",
  country: "China",
  countrycode: "CN",
  state: "Kwangsi",
  language: "chinese",
  languagecodes: "zh",
  votes: 4238,
  codec: "MP3",
  bitrate: 0,
  hls: 0,
  lastcheckok: 1,
  clickcount: 38,
  clicktrend: 38,
};

export const secondStationFixture: Station = {
  ...stationFixture,
  changeuuid: "change-2",
  stationuuid: "station-2",
  id: "station-2",
  name: "CNR-3 音乐之声",
  url: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
  urlResolved: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
  favicon: "bundle://cnr3_cover_v2",
};
