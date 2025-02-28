import { expect, test } from "@playwright/test";

import {
  containsAppFile,
  setupBackendServer,
} from "./utils/start_uieditor_backend";

//! If these don't work. Remember to first install the R package with `yarn
//! install-r-pkg` in `inst/r-package-build-tools` and then also build the
//! editor with `yarn build` (from `inst/editor` or the root.)
test("Template chooser can change between templates mid-session", async ({
  page,
  browserName,
}, info) => {
  test.skip(browserName !== "chromium", "Backend tests only need one browser");

  const backendServer = await setupBackendServer({
    app_dir_root: info.outputDir,
    printLogs: info.retry > 0,
  });

  await page.goto(backendServer.app_url);

  // The default state is no selection thus the proceed button shouldn't be allowed
  await expect(page.locator(`text=Select a template`)).toBeDisabled();

  // Select first available template
  await page
    .getByRole("article", { name: "App template preview card" })
    .first()
    .click();

  await page
    .getByRole("button", { name: "Start editor with selected template" })
    .click();

  // Wait for the edit view to be available be looking for the elements panel
  await expect(page.getByRole("heading", { name: "Elements" })).toBeVisible();

  // Reach into the app preview frame and grab the contents to be compared to the next app preview
  const previewAppBody = page
    .frameLocator(`[title="Application Preview"]`)
    .locator("body");
  await expect(previewAppBody).toBeVisible();

  const firstPreviewAppContents = await previewAppBody.innerHTML();

  const singleFileModeFiles = await backendServer.get_app_folder_contents();

  expect(containsAppFile(singleFileModeFiles, "app")).toBe(true);

  // Press back button
  await page.getByRole("button", { name: "Undo last change" }).click();

  // Make sure we're back in the template view
  await expect(page.locator(`text=Choose App Template`)).toBeVisible();

  // Select last template and go into editor
  await page
    .getByRole("article", { name: "App template preview card" })
    .last()
    .click();

  await page
    .getByRole("button", { name: "Start editor with selected template" })
    .click();

  await expect(page.getByRole("heading", { name: "Elements" })).toBeVisible();

  // Once again check the app preview contents and make sure...

  // 1) Preview is visible (app preview didn't crash) and ...
  await expect(previewAppBody).toBeVisible();

  // 2) The contents are different from the previous view (the actual app previewed changed)
  const secondPreviewAppContents = await previewAppBody.innerHTML();
  expect(firstPreviewAppContents).not.toBe(secondPreviewAppContents);
});

test("Ending on template chooser will clear any template files written", async ({
  page,
}, info) => {
  const backendServer = await setupBackendServer({
    app_dir_root: info.outputDir,
    printLogs: info.retry > 0,
  });

  await page.goto(backendServer.app_url);

  // Select first available template
  await page
    .getByRole("article", { name: "App template preview card" })
    .first()
    .click();

  await page
    .getByRole("button", { name: "Start editor with selected template" })
    .click();

  // Wait for the edit view to be available be looking for the elements panel
  await expect(page.getByRole("heading", { name: "Elements" })).toBeVisible();

  const inEditModeFiles = await backendServer.get_app_folder_contents();

  expect(Object.keys(inEditModeFiles).length).toBeGreaterThan(0);

  // Press back button
  await page.getByRole("button", { name: "Undo last change" }).click();

  // Make sure we're back in the template view
  await expect(page.locator(`text=Choose App Template`)).toBeVisible();

  // Close browser
  await page.close();

  // Wait for the server to be shut down
  await backendServer.serverClosed;

  // Now the app folder should be empty
  const afterCloseFiles = await backendServer.get_app_folder_contents();
  expect(Object.keys(afterCloseFiles).length).toEqual(0);
});
