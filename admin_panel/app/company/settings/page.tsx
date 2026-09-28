import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";

export default function CompanySettingsPage() {
  return (
    <>
      <PageHeader
        title="Тохиргоо"
        description="Компанийн профайл болон нэвтрэх мэдээлэл"
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader title="Компанийн профайл" />
          <CardBody className="space-y-4">
            <Input label="Компанийн нэр" defaultValue="MobiCom" />
            <Input label="Регистр" defaultValue="1234567" />
            <Input label="Утас" defaultValue="+976 8811 2233" />
            <Input label="Имэйл" defaultValue="ads@mobicom.mn" />
            <Button>Хадгалах</Button>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Нууц үг" />
          <CardBody className="space-y-4">
            <Input label="Одоогийн нууц үг" type="password" />
            <Input label="Шинэ нууц үг" type="password" />
            <Input label="Шинэ нууц үг давтах" type="password" />
            <Button>Шинэчлэх</Button>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
