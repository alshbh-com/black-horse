import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ArrowLeft, Save, Plug, CheckCircle2, AlertCircle, Copy } from "lucide-react";
import { toast } from "sonner";
import { useAdminAuth } from "@/contexts/AdminAuthContext";

const ApiIntegration = () => {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { logActivity } = useAdminAuth();
  const [apiKey, setApiKey] = useState("");
  const [webhookSecret, setWebhookSecret] = useState("");
  const [enabled, setEnabled] = useState(false);

  const projectRef = (import.meta.env.VITE_SUPABASE_URL || "").match(/https?:\/\/([^.]+)/)?.[1] || "";
  const webhookUrl = `https://${projectRef}.supabase.co/functions/v1/easyorders-webhook`;

  const { data: integ, isLoading } = useQuery({
    queryKey: ["api_integration_easyorders"],
    queryFn: async () => {
      const { data } = await supabase
        .from("api_integrations")
        .select("*")
        .eq("id", "easyorders")
        .maybeSingle();
      return data;
    },
  });

  useEffect(() => {
    if (integ) {
      setApiKey(integ.api_key || "");
      setWebhookSecret((integ as any).webhook_secret || "");
      setEnabled(!!integ.enabled);
    }
  }, [integ]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase
        .from("api_integrations")
        .update({ api_key: apiKey, webhook_secret: webhookSecret, enabled, updated_at: new Date().toISOString() } as any)
        .eq("id", "easyorders");
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("تم حفظ الإعدادات");
      logActivity("تحديث إعدادات EasyOrders API", "api_integration");
      qc.invalidateQueries({ queryKey: ["api_integration_easyorders"] });
    },
    onError: () => toast.error("فشل الحفظ"),
  });

  const copyUrl = async () => {
    await navigator.clipboard.writeText(webhookUrl);
    toast.success("تم نسخ رابط الويبهوك");
  };

  if (isLoading) return <div className="p-8 text-center">جاري التحميل...</div>;

  const status = integ?.last_sync_status;

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-accent/20 py-8">
      <div className="container mx-auto px-4 max-w-3xl">
        <Button onClick={() => navigate("/admin")} variant="ghost" className="mb-4">
          <ArrowLeft className="ml-2 h-4 w-4" /> رجوع
        </Button>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Plug className="h-5 w-5" /> تكامل EasyOrders (Webhook)
            </CardTitle>
            <CardDescription>
              EasyOrders ترسل كل طلب جديد فوراً عبر Webhook ويتم إضافته في قسم الأوردرات كـ "قيد الانتظار"
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="flex items-center justify-between rounded-lg border p-4">
              <div>
                <p className="font-medium">تفعيل استقبال الطلبات</p>
                <p className="text-sm text-muted-foreground">عند الإيقاف لن تُضاف الطلبات الجديدة</p>
              </div>
              <Switch checked={enabled} onCheckedChange={setEnabled} />
            </div>

            <div className="space-y-2 rounded-lg border p-4 bg-primary/5">
              <Label className="text-base font-bold">رابط الويبهوك (انسخه والصقه في EasyOrders)</Label>
              <div className="flex gap-2">
                <Input value={webhookUrl} readOnly dir="ltr" className="font-mono text-xs" />
                <Button onClick={copyUrl} variant="outline" size="icon"><Copy className="h-4 w-4" /></Button>
              </div>
              <ol className="text-xs text-muted-foreground space-y-1 list-decimal pr-4 mt-2">
                <li>ادخل لوحة EasyOrders ← Public API ← Webhooks</li>
                <li>اضغط Create Webhook والصق الرابط بالأعلى</li>
                <li>انسخ الـ secret الذي يظهر لك والصقه في الحقل أدناه (اختياري للتأمين)</li>
              </ol>
            </div>

            <div className="space-y-2">
              <Label>مفتاح API (Api-Key) - اختياري</Label>
              <Input
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="الصق مفتاح API الخاص بـ EasyOrders هنا"
                type="password"
              />
            </div>

            <div className="space-y-2">
              <Label>سر الويبهوك (Webhook Secret) - اختياري</Label>
              <Input
                value={webhookSecret}
                onChange={(e) => setWebhookSecret(e.target.value)}
                placeholder="الصق الـ secret الذي ظهر لك من EasyOrders"
                dir="ltr"
                type="password"
              />
              <p className="text-xs text-muted-foreground">
                إذا تركته فاضي، الويبهوك يقبل أي طلب. الأفضل تحطه للتأمين.
              </p>
            </div>

            <div className="flex gap-2">
              <Button onClick={() => saveMutation.mutate()} disabled={saveMutation.isPending}>
                <Save className="ml-2 h-4 w-4" />
                حفظ الإعدادات
              </Button>
            </div>

            <div className="rounded-lg border p-4 space-y-2 bg-muted/30">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">حالة آخر طلب مستلم:</span>
                {status === "success" && (
                  <Badge className="bg-green-500/15 text-green-700 dark:text-green-400 border-green-500/30">
                    <CheckCircle2 className="ml-1 h-3 w-3" /> ناجح
                  </Badge>
                )}
                {status === "error" && (
                  <Badge variant="destructive">
                    <AlertCircle className="ml-1 h-3 w-3" /> فشل
                  </Badge>
                )}
                {!status && <span className="text-sm text-muted-foreground">لا توجد بيانات بعد</span>}
              </div>
              {integ?.last_sync_at && (
                <p className="text-sm text-muted-foreground">
                  آخر استلام: {new Date(integ.last_sync_at).toLocaleString("ar-EG")}
                </p>
              )}
              {integ?.last_sync_message && (
                <p className="text-sm" dir="auto">{integ.last_sync_message}</p>
              )}
              <p className="text-sm">
                إجمالي الطلبات المستوردة: <span className="font-bold">{integ?.imported_count || 0}</span>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default ApiIntegration;
