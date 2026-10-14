import { ShieldCheck } from "lucide-react";
import { Card, CardBody, CardHeader } from "@uziy/ui";

/** The protections every number on this page obeys (backend StatisticsPrivacyPolicy). */
export function privacyRules(minGroupSize: number): string[] {
  return [
    "Зөвхөн 18+ насны, статистикт оролцохыг зөвшөөрсөн хэрэглэгчийн хариулт орно. Зөвшөөрлөө цуцалбал тэр даруй хасагдана.",
    `${minGroupSize}-аас цөөн хүнтэй бүлгийн тоо, хувийг хэзээ ч харуулахгүй. Шүүлтүүрээр нарийсгаж, хасалтаар хүн тодорхойлох боломжгүй.`,
    "Хүний тоог 10-аар доош бүхэлтгэж, хариултыг бүхэл хувиар харуулна.",
    "Чөлөөт текст хариулт, нэр, утас, төрсөн огноо, дүүрэг статистикт огт орохгүй. Зөвхөн хүйс, насны бүлэг, аймаг/хот.",
    "Энэ хуудсанд хандсан, файл татсан бүрийг хэн, хэзээ гэдгээр бүртгэнэ.",
  ];
}

export function PrivacyRulesCard({ minGroupSize }: { minGroupSize: number }) {
  return (
    <Card>
      <CardHeader
        title="Хамгаалалтын дүрэм"
        description="Энд гарах бүх тоо эдгээр дүрмийг дагана"
      />
      <CardBody>
        <ul className="space-y-2 text-sm text-[var(--color-text-secondary)]">
          {privacyRules(minGroupSize).map((rule) => (
            <li key={rule} className="flex gap-2">
              <ShieldCheck
                size={15}
                className="mt-0.5 shrink-0 text-[var(--color-success)]"
              />
              <span>{rule}</span>
            </li>
          ))}
        </ul>
      </CardBody>
    </Card>
  );
}
