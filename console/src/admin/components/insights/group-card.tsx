import { Card, CardBody, CardHeader } from "@uziy/ui";
import type { InsightGroup } from "@admin/lib/api";
import { groupFractions, peopleLabel } from "./insight-format";
import { ShareBar } from "./share-bar";

/** Consenting viewers per group (gender, age band or aimag); small groups show "< 50". */
export function GroupCard({
  title,
  groups,
  minGroupSize,
}: {
  title: string;
  groups: InsightGroup[];
  minGroupSize: number;
}) {
  const fractions = groupFractions(groups);
  return (
    <Card>
      <CardHeader title={title} />
      <CardBody className="space-y-3">
        {groups.map((g, i) => (
          <ShareBar
            key={g.label}
            label={g.label}
            value={peopleLabel(g.people, minGroupSize)}
            fraction={fractions[i]}
          />
        ))}
      </CardBody>
    </Card>
  );
}
