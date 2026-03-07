import {
  Action,
  ActionPanel,
  closeMainWindow,
  Form,
  Icon,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useState } from "react";

import {
  runFlo,
  runFloJson,
  type FloListProject,
  type FloListResult,
} from "./flo";

interface StartWorkValues {
  project: string;
  selector: string;
}

export default function Command() {
  const [projects, setProjects] = useState<FloListProject[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    void (async () => {
      try {
        const result = await runFloJson<FloListResult>(["list"]);
        setProjects(result.projects);
      } catch (error) {
        await showToast({
          style: Toast.Style.Failure,
          title: "Failed to load Flo projects",
          message: String(error),
        });
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const startWork = async (values: StartWorkValues) => {
    await showToast({
      style: Toast.Style.Animated,
      title: `Starting ${values.selector}`,
      message: values.project,
    });

    try {
      await runFlo(["start", values.selector, "--project", values.project]);
      await closeMainWindow();
      await showToast({
        style: Toast.Style.Success,
        title: `Started ${values.selector}`,
        message: values.project,
      });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Failed to start ${values.selector}`,
        message: String(error),
      });
    }
  };

  return (
    <Form
      isLoading={isLoading}
      navigationTitle="Start Flo Work"
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Start Work"
            icon={Icon.Rocket}
            onSubmit={(values) => void startWork(values as StartWorkValues)}
          />
        </ActionPanel>
      }
    >
      <Form.Dropdown id="project" title="Project">
        {projects.map((project) => (
          <Form.Dropdown.Item
            key={project.path}
            value={project.name}
            title={project.name}
          />
        ))}
      </Form.Dropdown>
      <Form.TextField
        id="selector"
        title="Selector"
        placeholder="123, gh:123, feat/cmux-launcher"
      />
    </Form>
  );
}
