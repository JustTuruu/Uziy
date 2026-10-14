import { Benefits } from "@/components/benefits";
import { FaqList } from "@/components/faq-list";
import { FinalCta } from "@/components/final-cta";
import { ForCompanies } from "@/components/for-companies";
import { Hero } from "@/components/hero";
import { HowItWorks } from "@/components/how-it-works";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { siteLinks } from "@/lib/links";

export default function LandingPage() {
  return (
    <>
      <a className="skip-link" href="#main-content">
        Үндсэн агуулга руу
      </a>
      <SiteHeader companyPanelUrl={siteLinks.companyPanel} />
      <main id="main-content" className="flex-1">
        <Hero links={siteLinks} />
        <div className="brand-strip">
          <div className="container">
            <span>ТАНИЛЦУУЛГААС ЦААШ.</span>
            <p>Таны бодол брэндийн дараагийн алхам.</p>
            <span aria-hidden>↗</span>
          </div>
        </div>
        <HowItWorks />
        <Benefits />
        <ForCompanies companyPanelUrl={siteLinks.companyPanel} />
        <FaqList />
        <FinalCta links={siteLinks} />
      </main>
      <SiteFooter year={new Date().getFullYear()} />
    </>
  );
}
