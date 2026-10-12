import { Benefits } from "@/components/benefits";
import { FaqList } from "@/components/faq-list";
import { FinalCta } from "@/components/final-cta";
import { ForCompanies } from "@/components/for-companies";
import { Hero } from "@/components/hero";
import { HowItWorks } from "@/components/how-it-works";
import { Marquee } from "@/components/marquee";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Statement } from "@/components/statement";
import { siteLinks } from "@/lib/links";

export default function LandingPage() {
  return (
    <>
      <SiteHeader companyPanelUrl={siteLinks.companyPanel} />
      <main className="flex-1">
        <Hero links={siteLinks} />
        <Marquee />
        <HowItWorks />
        <Statement />
        <Benefits />
        <FaqList />
        <ForCompanies companyPanelUrl={siteLinks.companyPanel} />
        <FinalCta links={siteLinks} />
      </main>
      <SiteFooter year={new Date().getFullYear()} />
    </>
  );
}
