import { closeMainWindow, showToast, Toast } from "@raycast/api";

import { runFlo } from "./flo";

export default async function Command() {
  await showToast({
    style: Toast.Style.Animated,
    title: "Opening last Flo workspace",
  });

  try {
    await runFlo(["open", "--last"]);
    await closeMainWindow();
    await showToast({
      style: Toast.Style.Success,
      title: "Opened last Flo workspace",
    });
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to open last Flo workspace",
      message: String(error),
    });
  }
}
