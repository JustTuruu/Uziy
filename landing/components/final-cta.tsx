import { FINAL_CTA } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { revealOrder } from "@/lib/reveal";
import { StoreButtons } from "./store-buttons";

export function FinalCta({ links }: { links: SiteLinks }) {
  return (
    <section id="download" className="download-section">
      <div className="container download-inner">
        <h2 data-reveal>{FINAL_CTA.title}</h2>
        <div className="download-copy" data-reveal style={revealOrder(1)}>
          <p>{FINAL_CTA.text}</p>
          <StoreButtons links={links} />
          {!links.appStore && !links.playStore && <small>{FINAL_CTA.soon}</small>}
        </div>
      </div>
    </section>
  );
}
