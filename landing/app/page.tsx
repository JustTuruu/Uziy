import { Benefits } from "@/components/benefits";
import { FaqList } from "@/components/faq-list";
import { ForCompanies } from "@/components/for-companies";
import { Hero } from "@/components/hero";
import { HowItWorks } from "@/components/how-it-works";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { siteLinks } from "@/lib/links";

export default function LandingPage() {
  return (
    <>
      <SiteHeader companyPanelUrl={siteLinks.companyPanel} />
      <main className="flex-1">
        <Hero links={siteLinks} />
        <HowItWorks />
        <Benefits />
        <FaqList />
        <ForCompanies companyPanelUrl={siteLinks.companyPanel} />
      </main>
      <SiteFooter year={new Date().getFullYear()} />
    </>
  );
}
