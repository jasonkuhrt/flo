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
  checkoutSelector,
  runFlo,
  runFloJson,
  type FloListProject,
  type FloListResult,
} from "./flo";

interface WorkspaceItem {
  project: FloListProject;
  checkout: FloListProject["checkouts"][number];
}

export default function Command() {
  const [items, setItems] = useState<WorkspaceItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    void (async () => {
      try {
        const result = await runFloJson<FloListResult>(["list"]);
        setItems(
          result.projects.flatMap((project) =>
            project.checkouts.map((checkout) => ({
              project,
              checkout,
            })),
          ),
        );
      } catch (error) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Failed to load Flo workspaces",
          message: String(error),
        });
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const openWorkspace = async (item: WorkspaceItem) => {
    const selector = checkoutSelector(item.project, item.checkout);

    await showToast({
      style: Toast.Style.Animated,
      title: `Opening ${selector}`,
    });

    try {
      await runFlo(["open", selector]);
      await closeMainWindow();
      await showToast({
        style: Toast.Style.Success,
        title: `Opened ${selector}`,
      });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Failed to open ${selector}`,
        message: String(error),
      });
    }
  };

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Search Flo projects and checkouts"
    >
      {items.map((item) => {
        const selector = checkoutSelector(item.project, item.checkout);
        const checkoutLabel = item.checkout.isMain
          ? "main"
          : (item.checkout.branch ?? basename(item.checkout.path));

        return (
          <List.Item
            key={selector}
            icon={
              item.checkout.workspaceOpen
                ? Icon.CircleProgress100
                : Icon.Terminal
            }
            title={item.project.name}
            subtitle={checkoutLabel}
            accessories={[
              { text: item.checkout.workspaceOpen ? "open" : "closed" },
              { text: item.checkout.path },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title="Open Workspace"
                  onAction={() => void openWorkspace(item)}
                />
                <Action
                  title="Copy Selector"
                  icon={Icon.Clipboard}
                  onAction={() => void Clipboard.copy(selector)}
                />
                <Action
                  title="Copy Path"
                  icon={Icon.Folder}
                  onAction={() => void Clipboard.copy(item.checkout.path)}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
