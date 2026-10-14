import { Apple, Play } from "lucide-react";
import type { SiteLinks } from "@/lib/links";
export const COMING_SOON_LABEL = "Удахгүй";
export function StoreButtons({
  links,
}: {
  links: Pick<SiteLinks, "appStore" | "playStore">;
}) {
  return (
    <div className="store-buttons">
      {[
        { store: "App Store", href: links.appStore, Icon: Apple },
        { store: "Google Play", href: links.playStore, Icon: Play },
      ].map(({ store, href, Icon }) => {
        const content = (
          <>
            <Icon size={23} aria-hidden />
            <span>
              <small>{href ? "Татаж авах" : COMING_SOON_LABEL}</small>
              <b>{store}</b>
            </span>
          </>
        );
        return href ? (
          <a className="store-button" href={href} key={store}>
            {content}
          </a>
        ) : (
          <button className="store-button" disabled key={store}>
            {content}
          </button>
        );
      })}
    </div>
  );
}
