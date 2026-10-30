import { CircleAlert, Info, TrendingUp } from "lucide-react";
import { Card, CardBody, CardHeader } from "@uziy/ui";
import type { Insight } from "@company/lib/analytics";

const TONE = {
  info: { icon: Info, color: "var(--color-accent)" },
  success: { icon: TrendingUp, color: "var(--color-success)" },
  warning: { icon: CircleAlert, color: "var(--color-warning)" },
} as const;

/**
 * The findings of the report in plain sentences. Each carries an icon as well
 * as a colour, so its meaning never depends on colour alone. Renders nothing
 * when there is nothing to say.
 */
export function InsightsCard({ insights }: { insights: readonly Insight[] }) {
  if (insights.length === 0) return null;
  return (
    <Card>
      <CardHeader title="Дүгнэлт" description="Тоонуудаас гарах гол санаа" />
      <CardBody>
        <ul className="space-y-3">
          {insights.map((insight) => {
            const { icon: Icon, color } = TONE[insight.tone];
            return (
              <li key={insight.text} className="flex items-start gap-3 text-sm">
                <Icon size={16} className="mt-0.5 shrink-0" style={{ color }} aria-hidden />
                <span className="text-[var(--color-text-primary)]">{insight.text}</span>
              </li>
            );
          })}
        </ul>
      </CardBody>
    </Card>
  );
}
