import { basename } from "pathe";

import {
  Action,
  ActionPanel,
  Clipboard,
  closeMainWindow,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useState } from "react";

import {
  runFlo,
  runFloJson,
  type FloRecentItem,
  type FloRecentResult,
} from "./flo";

export default function Command() {
  const [items, setItems] = useState<FloRecentItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    void (async () => {
      try {
        const result = await runFloJson<FloRecentResult>(["recent"]);
        setItems(result.items);
      } catch (error) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Failed to load recent Flo work",
          message: String(error),
        });
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const openRecentItem = async (item: FloRecentItem) => {
    await showToast({
      style: Toast.Style.Animated,
      title: `Opening ${item.selector}`,
    });

    try {
      await runFlo(["open", item.selector]);
      await closeMainWindow();
      await showToast({
        style: Toast.Style.Success,
        title: `Opened ${item.selector}`,
      });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Failed to open ${item.selector}`,
        message: String(error),
      });
    }
  };

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search recent Flo work">
      {items.map((item) => {
        const checkoutLabel = item.isMain
          ? "main"
          : (item.branch ?? basename(item.checkoutPath));

        return (
          <List.Item
            key={item.workspaceIdentity}
            icon={item.workspaceOpen ? Icon.CircleProgress100 : Icon.Clock}
            title={item.projectName}
            subtitle={checkoutLabel}
            accessories={[
              { text: item.lastAction },
              { text: item.workspaceOpen ? "open" : "closed" },
              {
                text: item.lastOpenedAt.replace("T", " ").replace(".000Z", "Z"),
              },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title="Open Workspace"
                  icon={Icon.Terminal}
                  onAction={() => void openRecentItem(item)}
                />
                <Action
                  title="Copy Selector"
                  icon={Icon.Clipboard}
                  onAction={() => void Clipboard.copy(item.selector)}
                />
                <Action
                  title="Copy Path"
                  icon={Icon.Folder}
                  onAction={() => void Clipboard.copy(item.checkoutPath)}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
