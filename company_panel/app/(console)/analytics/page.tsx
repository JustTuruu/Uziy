import { Card, CardBody, PageHeader } from "@uziy/ui";

export default function AnalyticsPage() {
  return (
    <>
      <PageHeader
        title="Аналитик"
        description="Судалгааны гүйцэтгэлийн харьцуулсан тайлан"
      />
      <Card>
        <CardBody className="py-16 text-center text-sm text-[var(--color-text-muted)]">
          Аналитик хэсэг удахгүй нээгдэнэ.
        </CardBody>
      </Card>
    </>
  );
}
