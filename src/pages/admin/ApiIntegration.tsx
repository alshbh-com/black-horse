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
import { ArrowLeft, RefreshCw, Save, Plug, CheckCircle2, AlertCircle } from "lucide-react";
import { toast } from "sonner";
import { useAdminAuth } from "@/contexts/AdminAuthContext";

const ApiIntegration = () => {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { logActivity } = useAdminAuth();
  const [apiKey, setApiKey] = useState("");
  const [apiUrl, setApiUrl] = useState("");
  const [enabled, setEnabled] = useState(false);
  const [syncing, setSyncing] = useState(false);

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
      setApiUrl(integ.api_url || "https://api.easy-orders.net/api/v1/external-app-orders");
      setEnabled(!!integ.enabled);
    }
  }, [integ]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase
        .from("api_integrations")
        .update({ api_key: apiKey, api_url: apiUrl, enabled, updated_at: new Date().toISOString() })
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

  const triggerSync = async () => {
    setSyncing(true);
    try {
      const { data, error } = await supabase.functions.invoke("easyorders-sync");
      if (error) throw error;
      if (data?.ok) {
        toast.success(`تم استيراد ${data.imported || 0} طلب جديد`);
      } else if (data?.skipped) {
        toast.warning("التكامل غير مفعّل أو المفتاح ناقص");
      } else {
        toast.error(data?.error || "فشلت المزامنة");
      }
      qc.invalidateQueries({ queryKey: ["api_integration_easyorders"] });
    } catch (e: any) {
      toast.error(e.message || "فشلت المزامنة");
    } finally {
      setSyncing(false);
    }
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
              <Plug className="h-5 w-5" /> تكامل EasyOrders API
            </CardTitle>
            <CardDescription>
              ربط متجر EasyOrders لجلب الطلبات تلقائياً كل دقيقتين وإضافتها في قسم الأوردرات كـ "قيد الانتظار"
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="flex items-center justify-between rounded-lg border p-4">
              <div>
                <p className="font-medium">تفعيل المزامنة التلقائية</p>
                <p className="text-sm text-muted-foreground">يجب إدخال مفتاح API صحيح أولاً</p>
              </div>
              <Switch checked={enabled} onCheckedChange={setEnabled} />
            </div>

            <div className="space-y-2">
              <Label>مفتاح API (Api-Key)</Label>
              <Input
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="الصق مفتاح API الخاص بـ EasyOrders هنا"
                type="password"
              />
              <p className="text-xs text-muted-foreground">
                تجده في لوحة EasyOrders ← الإعدادات ← API / تكاملات خارجية
              </p>
            </div>

            <div className="space-y-2">
              <Label>رابط API</Label>
              <Input value={apiUrl} onChange={(e) => setApiUrl(e.target.value)} dir="ltr" />
            </div>

            <div className="flex gap-2">
              <Button onClick={() => saveMutation.mutate()} disabled={saveMutation.isPending}>
                <Save className="ml-2 h-4 w-4" />
                حفظ الإعدادات
              </Button>
              <Button onClick={triggerSync} variant="outline" disabled={syncing || !apiKey}>
                <RefreshCw className={`ml-2 h-4 w-4 ${syncing ? "animate-spin" : ""}`} />
                مزامنة الآن
              </Button>
            </div>

            <div className="rounded-lg border p-4 space-y-2 bg-muted/30">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">حالة آخر مزامنة:</span>
                {status === "success" && (
                  <Badge className="bg-green-500/15 text-green-700 dark:text-green-400 border-green-500/30">
                    <CheckCircle2 className="ml-1 h-3 w-3" /> ناجحة
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
                  آخر مزامنة: {new Date(integ.last_sync_at).toLocaleString("ar-EG")}
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