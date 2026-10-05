int _int(Object? value) => (value as num?)?.toInt() ?? 0;

String _string(Object? value) => value as String? ?? '';

Map<String, Object?> _map(Object? value) =>
    (value as Map?)?.cast<String, Object?>() ?? const {};

/// Prices arrive in fen (1/100 CNY).
String lbFormatCents(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

class LbPlanDuration {
  final int quantity;

  /// Percent of the full price charged for this many units; 100 for none.
  final int discount;

  const LbPlanDuration({required this.quantity, this.discount = 100});
}

class LbPlan {
  final int id;
  final String name;
  final String description;
  final int unitPrice;
  final String unitTime;

  /// Bytes; 0 means unlimited.
  final int traffic;
  final List<LbPlanDuration> durations;

  const LbPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.unitPrice,
    required this.unitTime,
    required this.traffic,
    required this.durations,
  });

  /// Lists only what the website offers: the single unit unless the plan
  /// hides its original price, plus every discounted duration.
  factory LbPlan.fromPanel(Map<String, Object?> json) {
    final discounts = [
      for (final item in json['discount'] as List? ?? const [])
        LbPlanDuration(
          quantity: _int(_map(item)['quantity']),
          discount: _int(_map(item)['discount']),
        ),
    ].where((item) => item.quantity > 0);
    final durations = <int, LbPlanDuration>{
      if (json['show_original_price'] != false)
        1: const LbPlanDuration(quantity: 1),
      for (final item in discounts) item.quantity: item,
    };
    if (durations.isEmpty) {
      durations[1] = const LbPlanDuration(quantity: 1);
    }
    return LbPlan(
      id: _int(json['id']),
      name: _string(json['name']),
      description: _string(json['description']),
      unitPrice: _int(json['unit_price']),
      unitTime: _string(json['unit_time']),
      traffic: _int(json['traffic']),
      durations: durations.values.toList()
        ..sort((a, b) => a.quantity.compareTo(b.quantity)),
    );
  }

  String durationLabel(int quantity) {
    final unit = switch (unitTime.toLowerCase()) {
      'year' => '年',
      'month' => '个月',
      'day' => '天',
      'hour' => '小时',
      'minute' => '分钟',
      _ => unitTime,
    };
    return '$quantity $unit';
  }

  String durationChoiceLabel(LbPlanDuration duration) {
    final label = durationLabel(duration.quantity);
    if (duration.discount >= 100) return label;
    final tenths = duration.discount / 10;
    return '$label · '
        '${tenths.toStringAsFixed(duration.discount % 10 == 0 ? 0 : 1)} 折';
  }
}

/// Lists purchasable plans: `show` and `sell` on, in panel order.
List<LbPlan> lbSellablePlans(Object? data) {
  final list = _map(data)['list'] as List? ?? const [];
  return [
    for (final item in list)
      if (_map(item)['sell'] != false && _map(item)['show'] != false)
        LbPlan.fromPanel(_map(item)),
  ];
}

enum LbPaymentKind { balance, crypto, online }

class LbPaymentMethod {
  final int id;
  final String name;
  final String platform;

  static const balanceId = -1;

  /// The website groups these platforms as crypto; their checkout comes back
  /// as an on-site transfer instead of a cashier link.
  static const cryptoPlatforms = {'GMPay', 'Cryptomus'};

  const LbPaymentMethod({
    required this.id,
    required this.name,
    required this.platform,
  });

  factory LbPaymentMethod.fromPanel(Map<String, Object?> json) =>
      LbPaymentMethod(
        id: _int(json['id']),
        name: _string(json['name']),
        platform: _string(json['platform']),
      );

  LbPaymentKind get kind {
    if (id == balanceId) return LbPaymentKind.balance;
    if (cryptoPlatforms.contains(platform)) return LbPaymentKind.crypto;
    return LbPaymentKind.online;
  }
}

class LbQuote {
  final int amount;
  final int price;
  final int discount;
  final int fee;
  final int giftAmount;

  const LbQuote({
    required this.amount,
    required this.price,
    required this.discount,
    required this.fee,
    required this.giftAmount,
  });

  factory LbQuote.fromPanel(Map<String, Object?> json) => LbQuote(
    amount: _int(json['amount']),
    price: _int(json['price']),
    discount: _int(json['discount']),
    fee: _int(json['fee_amount']),
    giftAmount: _int(json['gift_amount']),
  );
}

enum LbOrderStatus { unknown, pending, paid, cancelled, closed, finished }

class LbOrder {
  final String orderNo;
  final LbOrderStatus status;
  final int amount;
  final int createdAt;
  final String paymentName;
  final String planName;
  final int quantity;

  const LbOrder({
    required this.orderNo,
    required this.status,
    required this.amount,
    required this.createdAt,
    required this.paymentName,
    required this.planName,
    required this.quantity,
  });

  factory LbOrder.fromPanel(Map<String, Object?> json) {
    final status = _int(json['status']);
    final payment = _map(json['payment']);
    return LbOrder(
      orderNo: _string(json['order_no']),
      status: status >= 0 && status < LbOrderStatus.values.length
          ? LbOrderStatus.values[status]
          : LbOrderStatus.unknown,
      amount: _int(json['amount']),
      createdAt: _int(json['created_at']),
      paymentName: _string(payment['name']).isNotEmpty
          ? _string(payment['name'])
          : _string(payment['platform']),
      planName: _string(_map(json['subscribe'])['name']),
      quantity: _int(json['quantity']),
    );
  }

  bool get isPaid =>
      status == LbOrderStatus.paid || status == LbOrderStatus.finished;

  bool get isOver =>
      status == LbOrderStatus.cancelled || status == LbOrderStatus.closed;
}

class LbCryptoPayment {
  final String address;

  /// Exact token amount, decimals included; a different one is not matched.
  final String amount;
  final String token;
  final String network;
  final String fiat;
  final String currency;

  /// Unix seconds.
  final int expiresAt;

  const LbCryptoPayment({
    required this.address,
    required this.amount,
    required this.token,
    required this.network,
    required this.fiat,
    required this.currency,
    required this.expiresAt,
  });

  factory LbCryptoPayment.fromPanel(Map<String, Object?> json) =>
      LbCryptoPayment(
        address: _string(json['address']),
        amount: _string(json['amount']),
        token: _string(json['token']),
        network: _string(json['network']),
        fiat: _string(json['fiat']),
        currency: _string(json['currency']),
        expiresAt: _int(json['expires_at']),
      );

  /// What a wallet's send screen calls the network, then the chain.
  String get networkLabel => switch (network) {
    'tron' => 'TRC20 · TRON',
    'binance' => 'BEP20 · BSC',
    'ethereum' => 'ERC20 · Ethereum',
    'polygon' => 'Polygon · Polygon PoS',
    'solana' => 'SPL · Solana',
    'ton' => 'TON',
    _ => network.toUpperCase(),
  };
}

class LbCheckout {
  /// `url`, `qr`, `crypto`, `balance` or `stripe`.
  final String type;
  final String checkoutUrl;
  final LbCryptoPayment? crypto;

  const LbCheckout({
    required this.type,
    required this.checkoutUrl,
    this.crypto,
  });

  factory LbCheckout.fromPanel(Map<String, Object?> json) {
    final crypto = json['crypto'];
    return LbCheckout(
      type: _string(json['type']),
      checkoutUrl: _string(json['checkout_url']),
      crypto: crypto is Map
          ? LbCryptoPayment.fromPanel(crypto.cast<String, Object?>())
          : null,
    );
  }
}
