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

interface WorkItem {
  project: FloListProject;
  checkout: FloListProject["checkouts"][number];
}

export default function Command() {
  const [items, setItems] = useState<WorkItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    void (async () => {
      try {
        const result = await runFloJson<FloListResult>(["list"]);
        setItems(
          result.projects.flatMap((project) =>
            project.checkouts
              .filter((checkout) => !checkout.isMain)
              .map((checkout) => ({
                project,
                checkout,
              })),
          ),
        );
      } catch (error) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Failed to load Flo work",
          message: String(error),
        });
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const endWork = async (item: WorkItem, openMain: boolean) => {
    const selector = checkoutSelector(item.project, item.checkout);
    const args = openMain
      ? ["end", selector, "--open-main"]
      : ["end", selector];

    await showToast({
      style: Toast.Style.Animated,
      title: `Ending ${selector}`,
    });

    try {
      await runFlo(args);
      await closeMainWindow();
      await showToast({
        style: Toast.Style.Success,
        title: openMain
          ? `Ended ${selector} and opened main`
          : `Ended ${selector}`,
      });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Failed to end ${selector}`,
        message: String(error),
      });
    }
  };

  return (
    <List isLoading={isLoading} searchBarPlaceholder="End Flo feature work">
      {items.map((item) => {
        const selector = checkoutSelector(item.project, item.checkout);
        const checkoutLabel =
          item.checkout.branch ?? basename(item.checkout.path);

        return (
          <List.Item
            key={selector}
            icon={item.checkout.workspaceOpen ? Icon.XmarkCircle : Icon.Circle}
            title={item.project.name}
            subtitle={checkoutLabel}
            accessories={[
              { text: item.checkout.workspaceOpen ? "open" : "closed" },
              { text: item.checkout.path },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title="End Work"
                  icon={Icon.XmarkCircle}
                  onAction={() => void endWork(item, false)}
                />
                <Action
                  title="End Work and Open Main"
                  icon={Icon.ArrowLeft}
                  onAction={() => void endWork(item, true)}
                />
                <Action
                  title="Copy Selector"
                  icon={Icon.Clipboard}
                  onAction={() => void Clipboard.copy(selector)}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
