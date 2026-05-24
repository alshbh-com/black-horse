import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { ArrowLeft, Printer, FileSpreadsheet, Filter, Building2, Search, ChevronDown, X } from "lucide-react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useState, useMemo, useEffect } from "react";
import * as XLSX from "xlsx";
import { useTheme } from "@/contexts/ThemeContext";
import { generateBarcodeDataUrl } from "@/lib/barcodeUtils";


const Invoices = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { invoiceName } = useTheme();
  const [selectedOrders, setSelectedOrders] = useState<string[]>([]);
  const [selectedOfficeId, setSelectedOfficeId] = useState<string>("default");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [partialDeliveryNotes, setPartialDeliveryNotes] = useState<Record<string, string>>({});
  const [printCopies, setPrintCopies] = useState<number>(1);

  // Auto-select orders when arriving from Barcode Scanner with ?ids=...
  useEffect(() => {
    const idsParam = searchParams.get("ids");
    if (idsParam) {
      setSelectedOrders(idsParam.split(",").filter(Boolean));
    }
  }, [searchParams]);

  
  // فلاتر
  const [dateFilter, setDateFilter] = useState<string>("");
  const [governorateFilter, setGovernorateFilter] = useState<string[]>([]);

  const { data: orders, isLoading } = useQuery({
    queryKey: ["orders-for-invoices"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("orders")
        .select(`
          *,
          customers (name, phone, address, governorate, phone2),
          delivery_agents (name, serial_number),
          governorates (name, shipping_cost),
          order_items (*, products (name))
        `)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data;
    },
  });

  // جلب المحافظات للفلتر
  const { data: governorates } = useQuery({
    queryKey: ["governorates-filter"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("governorates")
        .select("id, name")
        .order("name");
      if (error) throw error;
      return data;
    },
  });

  // جلب المكاتب
  const { data: offices } = useQuery({
    queryKey: ["offices"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("offices")
        .select("*")
        .eq("is_active", true)
        .order("name");
      if (error) throw error;
      return data;
    },
  });

  // تحويل التاريخ ليوم Cairo
  const getDateKey = (value: string | Date) => {
    const d = typeof value === "string" ? new Date(value) : value;
    return new Intl.DateTimeFormat("en-CA", {
      timeZone: "Africa/Cairo",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(d);
  };

  // استخراج التواريخ الفريدة من الأوردرات
  const uniqueDates = useMemo(() => {
    if (!orders?.length) return [];
    const dates = new Set<string>();
    orders.forEach(order => {
      dates.add(getDateKey(order.created_at));
    });
    return Array.from(dates).sort().reverse();
  }, [orders]);

  // فلترة الأوردرات
  const filteredOrders = useMemo(() => {
    if (!orders?.length) return [];
    
    return orders.filter(order => {
      // بحث برقم الأوردر
      if (searchQuery) {
        const orderNum = (order.order_number || "").toString();
        const orderId = order.id.slice(0, 8);
        const customerName = order.customers?.name || "";
        const q = searchQuery.trim();
        if (!orderNum.includes(q) && !orderId.includes(q) && !customerName.includes(q)) return false;
      }
      
      // فلتر التاريخ
      if (dateFilter) {
        const orderDate = getDateKey(order.created_at);
        if (orderDate !== dateFilter) return false;
      }
      
      // فلتر المحافظة (متعدد)
      if (governorateFilter.length > 0) {
        const orderGov = order.governorates?.name || order.customers?.governorate || "";
        if (!governorateFilter.includes(orderGov)) return false;
      }
      
      return true;
    });
  }, [orders, dateFilter, governorateFilter, searchQuery]);

  // تصدير Excel للأوردرات المفلترة/المحددة فقط
  const handleExportExcel = () => {
    // إذا كان هناك أوردرات محددة، صدّرها فقط، وإلا صدّر المفلتر
    const ordersToExport = selectedOrders.length > 0 
      ? filteredOrders.filter(o => selectedOrders.includes(o.id))
      : filteredOrders;
    
    if (!ordersToExport?.length) {
      return;
    }
    
    const exportData = ordersToExport.map(order => {
      const totalAmount = parseFloat(order.total_amount.toString());
      const customerShipping = parseFloat((order.shipping_cost || 0).toString());
      const agentShipping = parseFloat((order.agent_shipping_cost || 0).toString());
      const totalPrice = totalAmount + customerShipping;
      const netAmount = totalPrice - agentShipping;
      
      return {
        "رقم الأوردر": order.order_number || order.id.slice(0, 8),
        "اسم العميل": order.customers?.name || "-",
        "الهاتف": order.customers?.phone || "-",
        "العنوان": order.customers?.address || "-",
        "المحافظة": order.governorates?.name || order.customers?.governorate || "-",
        "المندوب": order.delivery_agents?.name || "-",
        "الحالة": order.status,
        "سعر المنتجات": totalAmount.toFixed(2),
        "شحن العميل": customerShipping.toFixed(2),
        "الإجمالي": totalPrice.toFixed(2),
        "شحن المندوب": agentShipping.toFixed(2),
        "الصافي (المطلوب من المندوب)": netAmount.toFixed(2),
        "الخصم": parseFloat((order.discount || 0).toString()).toFixed(2),
        "التاريخ": new Date(order.created_at).toLocaleDateString("ar-EG")
      };
    });

    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "الأوردرات");
    
    const fileName = dateFilter 
      ? `orders_${dateFilter}.xlsx`
      : `orders_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(wb, fileName);
  };

  const generateInvoiceCell = (order: any, brandName: string, watermarkText: string, logoUrl: string | null) => {
    const totalAmount = parseFloat(order.total_amount.toString());
    const customerShipping = parseFloat((order.shipping_cost || 0).toString());
    const totalPrice = totalAmount + customerShipping;
    
    const logoHtml = logoUrl 
      ? `<img src="${logoUrl}" style="max-width:40px;max-height:40px;object-fit:contain;" />`
      : '';
    
    const orderNo = order.order_number || order.id.slice(0, 8);
    const itemsCount = order.order_items?.reduce((s: number, it: any) => s + (it.quantity || 1), 0) || 0;

    const rowsHtml = (order.order_items || []).map((item: any) => {
      const quantity = item.quantity || 1;
      const itemTotal = parseFloat(item.price.toString()) * quantity;
      let productName = item.products?.name;
      let itemSize = item.size;
      let itemColor = item.color;
      if (!productName && item.product_details) {
        try {
          const details = typeof item.product_details === 'string'
            ? JSON.parse(item.product_details)
            : item.product_details;
          productName = details?.name || details?.product_name;
          itemSize = itemSize || details?.size;
          itemColor = itemColor || details?.color;
        } catch {
          if (typeof item.product_details === 'string' && item.product_details.trim()) {
            productName = item.product_details;
          }
        }
      }
      return `<tr>
        <td style="border-bottom:1px solid #e5e5e5;padding:5px 6px;font-size:12px;color:#111;">${productName || '-'}</td>
        <td style="border-bottom:1px solid #e5e5e5;padding:5px 6px;text-align:center;font-size:12px;color:#444;">${itemSize || '-'}</td>
        <td style="border-bottom:1px solid #e5e5e5;padding:5px 6px;text-align:center;font-size:12px;color:#444;">${itemColor || '-'}</td>
        <td style="border-bottom:1px solid #e5e5e5;padding:5px 6px;text-align:center;font-size:12px;font-weight:700;">${quantity}</td>
        <td style="border-bottom:1px solid #e5e5e5;padding:5px 6px;text-align:left;font-size:12px;font-weight:700;">${itemTotal.toFixed(0)} ج.م</td>
      </tr>`;
    }).join('');

    return `<div class="invoice-cell">
      <div style="position:relative;width:100%;height:100%;padding:5mm;box-sizing:border-box;font-family:Arial,sans-serif;display:flex;flex-direction:column;background:#fff;">
        <div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%) rotate(-30deg);font-size:42px;font-weight:900;color:rgba(0,0,0,0.05);pointer-events:none;z-index:0;white-space:nowrap;letter-spacing:4px;">${watermarkText}</div>

        <div style="position:relative;z-index:1;display:flex;flex-direction:column;height:100%;">

          <!-- 1) HEADER : brand + invoice meta -->
          <div style="display:flex;justify-content:space-between;align-items:center;padding-bottom:6px;border-bottom:2px solid #111;">
            <div style="display:flex;align-items:center;gap:8px;">
              ${logoHtml}
              <div style="display:flex;flex-direction:column;line-height:1.1;">
                <span style="font-size:18px;font-weight:900;color:#111;letter-spacing:1px;">${brandName}</span>
                <span style="font-size:9px;color:#888;letter-spacing:3px;">INVOICE / فاتورة</span>
              </div>
            </div>
            <div style="text-align:left;">
              <div style="font-size:9px;color:#888;letter-spacing:1px;">رقم الفاتورة</div>
              <div style="font-size:17px;font-weight:900;color:#d4af37;">#${orderNo}</div>
              <div style="font-size:9px;color:#666;margin-top:1px;">${new Date(order.created_at).toLocaleDateString('ar-EG')}</div>
            </div>
          </div>

          <!-- 2) BARCODE -->
          <div style="text-align:center;padding:5px 0 3px;border-bottom:1px dashed #ccc;">
            <img src="${generateBarcodeDataUrl(order.tracking_code || `ORD-${orderNo}`, { width: 1.5, height: 32, fontSize: 10, margin: 0 })}" style="max-height:38px;" />
          </div>

          <!-- 3) CUSTOMER -->
          <div style="padding:6px 4px;border-bottom:1px dashed #ccc;">
            <div style="font-size:9px;color:#888;letter-spacing:2px;margin-bottom:3px;">بيانات العميل</div>
            <div style="font-size:13px;font-weight:700;color:#111;margin-bottom:2px;">${order.customers?.name || '-'}</div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:2px 8px;font-size:11px;color:#333;line-height:1.5;">
              <div><span style="color:#888;">هاتف:</span> ${order.customers?.phone || '-'}</div>
              <div><span style="color:#888;">محافظة:</span> ${order.governorates?.name || order.customers?.governorate || '-'}</div>
              ${order.customers?.phone2 ? `<div><span style="color:#888;">هاتف 2:</span> ${order.customers.phone2}</div>` : ''}
              <div><span style="color:#888;">المندوب:</span> ${order.delivery_agents?.name || '—'}</div>
            </div>
            <div style="font-size:11px;color:#333;margin-top:3px;"><span style="color:#888;">العنوان:</span> ${order.customers?.address || '-'}</div>
            ${order.notes ? `<div style="font-size:10px;color:#666;margin-top:3px;font-style:italic;">ملاحظة: ${order.notes}</div>` : ''}
          </div>

          <!-- 4) ITEMS -->
          <div style="flex:1;padding:5px 0;overflow:hidden;">
            <table style="width:100%;border-collapse:collapse;">
              <thead>
                <tr>
                  <th style="text-align:right;padding:4px 6px;background:#111;color:#fff;font-size:10px;letter-spacing:1px;font-weight:700;">المنتج</th>
                  <th style="padding:4px 6px;background:#111;color:#fff;font-size:10px;letter-spacing:1px;font-weight:700;">المقاس</th>
                  <th style="padding:4px 6px;background:#111;color:#fff;font-size:10px;letter-spacing:1px;font-weight:700;">اللون</th>
                  <th style="padding:4px 6px;background:#111;color:#fff;font-size:10px;letter-spacing:1px;font-weight:700;">الكمية</th>
                  <th style="text-align:left;padding:4px 6px;background:#111;color:#fff;font-size:10px;letter-spacing:1px;font-weight:700;">السعر</th>
                </tr>
              </thead>
              <tbody>${rowsHtml}</tbody>
            </table>
          </div>

          <!-- 5) TOTALS -->
          <div style="display:flex;justify-content:space-between;align-items:stretch;gap:6px;margin-top:4px;">
            <div style="flex:1;font-size:10px;color:#555;display:flex;flex-direction:column;justify-content:center;padding:0 4px;">
              <div>عدد القطع: <strong style="color:#111;">${itemsCount}</strong></div>
              <div style="margin-top:2px;">المنتجات: <strong style="color:#111;">${totalAmount.toFixed(0)} ج.م</strong></div>
              <div style="margin-top:2px;">الشحن: <strong style="color:#111;">${customerShipping.toFixed(0)} ج.م</strong></div>
            </div>
            <div style="background:#d4af37;color:#111;padding:8px 12px;border-radius:4px;text-align:center;min-width:42%;">
              <div style="font-size:9px;letter-spacing:2px;font-weight:700;opacity:0.85;">المبلغ المطلوب</div>
              <div style="font-size:22px;font-weight:900;line-height:1.1;margin-top:2px;">${totalPrice.toFixed(0)} <span style="font-size:11px;">ج.م</span></div>
            </div>
          </div>

          ${partialDeliveryNotes[order.id] ? `<div style="margin-top:4px;border:1px solid #d4af37;border-radius:3px;padding:3px 6px;font-size:10px;background:#fffdf0;color:#7a5e00;"><strong>⚠ تسليم جزئي:</strong> ${partialDeliveryNotes[order.id]}</div>` : ''}

          <!-- 6) FOOTER : terms -->
          <div style="margin-top:5px;padding-top:5px;border-top:1px solid #111;">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:1px 10px;font-size:9px;line-height:1.4;color:#444;">
              <div>• معاينة الأوردر قبل الاستلام.</div>
              <div>• الشحن تابع لشركة الشحن.</div>
              <div>• لا مسؤولية بعد الاستلام.</div>
              <div>• للشكاوى تواصل مع المقر.</div>
            </div>
            <div style="margin-top:4px;display:flex;justify-content:space-between;align-items:center;font-size:9px;color:#888;letter-spacing:1px;">
              <span>${brandName}</span>
              <span>— شكراً لتعاملكم معنا —</span>
            </div>
          </div>

        </div>
      </div>
    </div>`;
  };

  const handlePrint = () => {
    const ordersToPrint = filteredOrders?.filter(o => selectedOrders.includes(o.id));
    if (!ordersToPrint?.length) return;

    const selectedOffice = offices?.find((o: any) => o.id === selectedOfficeId);
    const brandName = selectedOffice ? selectedOffice.name : invoiceName;
    const watermarkText = selectedOffice ? (selectedOffice.watermark_name || selectedOffice.name) : invoiceName;
    const logoUrl = selectedOffice?.logo_url || null;

    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const cells: string[] = [];
    for (let c = 0; c < printCopies; c++) {
      ordersToPrint.forEach(order => {
        cells.push(generateInvoiceCell(order, brandName, watermarkText, logoUrl));
      });
    }

    let pagesHTML = '';
    for (let i = 0; i < cells.length; i += 4) {
      const pageCells = cells.slice(i, i + 4);
      while (pageCells.length < 4) {
        pageCells.push('<div class="invoice-cell"></div>');
      }
      pagesHTML += `<div class="page">${pageCells.join('')}</div>`;
    }

    printWindow.document.write(`<html dir="rtl"><head><title>طباعة الفواتير</title>
      <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:Arial,sans-serif}
        .page{width:210mm;height:297mm;display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;gap:0;page-break-after:always}
        .page:last-child{page-break-after:auto}
        .invoice-cell{width:105mm;height:148.5mm;border:0.5px dashed #ccc;overflow:hidden;box-sizing:border-box}
        @page{margin:0;size:A4}
        @media print{.invoice-cell{border:0.5px dashed #bbb}}
      </style></head><body>${pagesHTML}</body></html>`);
    printWindow.document.close();
    setTimeout(() => printWindow.print(), 150);
  };

  // تحديد/إلغاء تحديد الكل
  const handleSelectAll = () => {
    if (selectedOrders.length === filteredOrders.length) {
      setSelectedOrders([]);
    } else {
      setSelectedOrders(filteredOrders.map(o => o.id));
    }
  };

  if (isLoading) return <div className="p-8">جاري التحميل...</div>;

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-accent/20 py-8">
      <div className="container mx-auto px-4">
        <Button onClick={() => navigate("/admin")} variant="ghost" className="mb-4">
          <ArrowLeft className="ml-2 h-4 w-4" />
          رجوع
        </Button>
        <Card>
          <CardHeader className="flex flex-col gap-4">
            <div className="flex flex-row items-center justify-between flex-wrap gap-4">
              <CardTitle>الفواتير</CardTitle>
              <div className="flex gap-2 flex-wrap">
                <Button onClick={handleExportExcel} disabled={filteredOrders.length === 0}>
                  <FileSpreadsheet className="ml-2 h-4 w-4" />
                  تصدير Excel {selectedOrders.length > 0 ? `(${selectedOrders.length})` : `(${filteredOrders.length})`}
                </Button>
                <Button onClick={handlePrint} disabled={selectedOrders.length === 0}>
                  <Printer className="ml-2 h-4 w-4" />
                  طباعة ({selectedOrders.length})
                </Button>
                <div className="flex items-center gap-1">
                  <Label className="text-xs whitespace-nowrap">نسخ:</Label>
                  <Input
                    type="number"
                    min={1}
                    max={10}
                    value={printCopies}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        setPrintCopies(1);
                        return;
                      }
                      const num = parseInt(val);
                      if (!isNaN(num)) {
                        setPrintCopies(Math.max(1, Math.min(10, num)));
                      }
                    }}
                    className="w-16 h-9 text-center"
                  />
                </div>
              </div>
            </div>
            
            {/* البحث والفلاتر */}
            <div className="flex items-end gap-4 flex-wrap p-4 bg-muted/50 rounded-lg">
              <div className="flex flex-col gap-1">
                <Label className="text-xs">بحث برقم الأوردر أو الاسم</Label>
                <div className="relative">
                  <Search className="absolute right-2 top-2.5 h-4 w-4 text-muted-foreground" />
                  <Input
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="ابحث..."
                    className="w-44 pr-8"
                  />
                </div>
              </div>
              
              <div className="flex flex-col gap-1">
                <Label className="text-xs">التاريخ</Label>
                <Select value={dateFilter} onValueChange={setDateFilter}>
                  <SelectTrigger className="w-40">
                    <SelectValue placeholder="كل الأيام" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">كل الأيام</SelectItem>
                    {uniqueDates.map((date) => (
                      <SelectItem key={date} value={date}>
                        {new Date(date).toLocaleDateString('ar-EG')}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <div className="flex flex-col gap-1">
                <Label className="text-xs">المحافظة</Label>
                <Popover>
                  <PopoverTrigger asChild>
                    <Button variant="outline" size="sm" className="w-48 justify-between font-normal">
                      <span className="truncate">
                        {governorateFilter.length === 0
                          ? "كل المحافظات"
                          : governorateFilter.length === 1
                          ? governorateFilter[0]
                          : `${governorateFilter.length} محافظات`}
                      </span>
                      <ChevronDown className="h-4 w-4 opacity-50 shrink-0" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-56 p-2 max-h-72 overflow-y-auto" align="start">
                    <div className="flex items-center justify-between mb-2 pb-2 border-b">
                      <button
                        type="button"
                        className="text-xs text-primary hover:underline"
                        onClick={() => setGovernorateFilter(governorates?.map((g) => g.name) || [])}
                      >
                        تحديد الكل
                      </button>
                      <button
                        type="button"
                        className="text-xs text-muted-foreground hover:underline"
                        onClick={() => setGovernorateFilter([])}
                      >
                        مسح
                      </button>
                    </div>
                    {governorates?.map((gov) => {
                      const checked = governorateFilter.includes(gov.name);
                      return (
                        <label
                          key={gov.id}
                          className="flex items-center gap-2 py-1 px-1 rounded hover:bg-accent cursor-pointer"
                        >
                          <Checkbox
                            checked={checked}
                            onCheckedChange={(c) => {
                              setGovernorateFilter((prev) =>
                                c ? [...prev, gov.name] : prev.filter((n) => n !== gov.name)
                              );
                            }}
                          />
                          <span className="text-sm">{gov.name}</span>
                        </label>
                      );
                    })}
                  </PopoverContent>
                </Popover>
              </div>
              
              <div className="flex flex-col gap-1">
                <Label className="text-xs">المكتب (للفاتورة)</Label>
                <Select value={selectedOfficeId} onValueChange={setSelectedOfficeId}>
                  <SelectTrigger className="w-48">
                    <SelectValue placeholder="المكتب الافتراضي" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="default">الافتراضي ({invoiceName})</SelectItem>
                    {offices?.map((office: any) => (
                      <SelectItem key={office.id} value={office.id}>
                        {office.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => {
                  setDateFilter("");
                  setGovernorateFilter([]);
                  setSearchQuery("");
                }}
              >
                مسح الفلاتر
              </Button>
              
              <div className="mr-auto text-sm text-muted-foreground">
                عدد النتائج: {filteredOrders.length}
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {filteredOrders.length > 0 && (
              <div className="mb-4">
                <Button variant="outline" size="sm" onClick={handleSelectAll}>
                  {selectedOrders.length === filteredOrders.length ? "إلغاء تحديد الكل" : "تحديد الكل"}
                </Button>
              </div>
            )}
            <div className="space-y-2">
              {filteredOrders?.map((order) => {
                const totalAmount = parseFloat(order.total_amount.toString());
                const customerShipping = parseFloat((order.shipping_cost || 0).toString());
                const agentShipping = parseFloat((order.agent_shipping_cost || 0).toString());
                const totalPrice = totalAmount + customerShipping;
                const netAmount = totalPrice - agentShipping;
                
                return (
                  <div key={order.id} className="flex items-start gap-4 p-4 border rounded">
                    <Checkbox
                      checked={selectedOrders.includes(order.id)}
                      onCheckedChange={(checked) => {
                        setSelectedOrders(checked 
                          ? [...selectedOrders, order.id]
                          : selectedOrders.filter(id => id !== order.id)
                        );
                      }}
                      className="mt-1"
                    />
                    <div className="flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-xs font-mono bg-primary/10 text-primary px-1.5 py-0.5 rounded">#{order.order_number || order.id.slice(0, 8)}</span>
                        <p className="font-bold">{order.customers?.name}</p>
                        <span className="text-xs px-2 py-0.5 rounded bg-muted">
                          {order.governorates?.name || order.customers?.governorate || "-"}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {new Date(order.created_at).toLocaleDateString('ar-EG')}
                        </span>
                      </div>
                      <p className="text-sm text-muted-foreground">
                        الإجمالي: {totalPrice.toFixed(2)} ج.م | الصافي المطلوب من المندوب: {netAmount.toFixed(2)} ج.م
                      </p>
                      {selectedOrders.includes(order.id) && (
                        <div className="mt-2">
                          <Label className="text-xs">تسليم جزئي (اختياري)</Label>
                          <Textarea
                            value={partialDeliveryNotes[order.id] || ""}
                            onChange={(e) => setPartialDeliveryNotes(prev => ({...prev, [order.id]: e.target.value}))}
                            placeholder="مثال: قطعة واحدة بـ 150 ج.م، قطعتين بـ 300 ج.م"
                            rows={2}
                            className="mt-1 text-sm"
                          />
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
              
              {filteredOrders.length === 0 && (
                <p className="text-center text-muted-foreground py-8">
                  لا توجد فواتير تطابق الفلاتر المحددة
                </p>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Invoices;