import { PageHeader } from "@/components/page-header";
import { Card, CardBody } from "@/components/ui/card";

export default function AnalyticsPage() {
  return (
    <>
      <PageHeader
        title="Аналитик"
        description="Кампаниудын гүйцэтгэлийн харьцуулсан тайлан"
      />
      <Card>
        <CardBody className="py-16 text-center text-sm text-[var(--color-text-muted)]">
          Аналитик хэсэг удахгүй нээгдэнэ.
        </CardBody>
      </Card>
    </>
  );
}
