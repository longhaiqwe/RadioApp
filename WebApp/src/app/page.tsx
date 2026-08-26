import { presetStations } from "@/data/presetStations";
import { HomeClient } from "./HomeClient";

export default function Home() {
  return <HomeClient initialTopStations={presetStations} />;
}
