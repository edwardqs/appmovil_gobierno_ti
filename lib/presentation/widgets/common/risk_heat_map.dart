import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:math';

class RiskHeatMap extends StatefulWidget {
  const RiskHeatMap({super.key});

  @override
  State<RiskHeatMap> createState() => _RiskHeatMapState();
}

class _RiskHeatMapState extends State<RiskHeatMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Datos simulados. En una app real, vendrían del risk_service.
  final List<List<int>> riskData = List.generate(
      5, (i) => List.generate(5, (j) => Random().nextInt(5)));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForRisk(int probability, int impact) {
    final score = (probability + 1) * (impact + 1);
    if (score >= 20) return AppColors.criticalRisk;
    if (score >= 13) return AppColors.highRisk;
    if (score >= 7) return AppColors.mediumRisk;
    return AppColors.lowRisk;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text('Impacto →', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Row(
                children: [
                  RotatedBox(
                    quarterTurns: -1,
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text('Probabilidad →',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: 25,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        int row = 4 - (index ~/ 5); // Probabilidad (y)
                        int col = index % 5; // Impacto (x)
                        final cellValue = riskData[row][col];
                        final animation = Tween<double>(begin: 0.0, end: 1.0)
                            .animate(CurvedAnimation(
                          parent: _controller,
                          curve: Interval(
                            (index / 25) * 0.5,
                            min(1.0, (index / 25) * 0.5 + 0.5),
                            curve: Curves.easeOut,
                          ),
                        ));

                        return ScaleTransition(
                          scale: animation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getColorForRisk(row, col),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                cellValue.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
