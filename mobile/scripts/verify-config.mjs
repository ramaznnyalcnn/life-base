import { readFileSync } from "node:fs";

const packageJson = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
const appJson = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));

const requiredDependencies = [
  "expo",
  "react",
  "react-native",
  "expo-notifications",
  "expo-secure-store",
  "@react-native-async-storage/async-storage"
];

const missingDependencies = requiredDependencies.filter(
  (name) => !packageJson.dependencies || !packageJson.dependencies[name]
);

if (missingDependencies.length) {
  throw new Error(`Missing dependencies: ${missingDependencies.join(", ")}`);
}

if (!appJson.expo?.android?.package) {
  throw new Error("app.json must define expo.android.package");
}

if (appJson.expo?.android?.usesCleartextTraffic !== true) {
  throw new Error("Tailscale HTTP setup expects android.usesCleartextTraffic=true");
}

console.log("mobile config ok");
