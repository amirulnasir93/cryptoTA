import { Link } from "react-router-dom";

// Shown instead of a loading/error state when the app has no Sheet ID / Web
// Client ID yet or the user hasn't signed in with Google this session --
// isReady() gates every data query off, so without this pages would just
// show a bare "failed to load" with no indication of what to actually do.
export function NotConfiguredNotice() {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 text-sm dark:border-neutral-800 dark:bg-neutral-900">
      <p className="text-neutral-600 dark:text-neutral-300">
        Finish setup on the{" "}
        <Link to="/settings" className="underline">
          Settings
        </Link>{" "}
        page -- add your Sheet ID and Web Client ID, then sign in with Google -- before this page has anything to
        show.
      </p>
    </div>
  );
}
