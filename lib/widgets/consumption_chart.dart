import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Widget affichant un graphique de consommation mensuelle d'énergie.
///
/// [monthlyData] : Liste des valeurs de consommation mensuelle
/// [title] : Titre du graphique
/// [barColor] : Couleur des barres du graphique
class ConsumptionChart extends StatelessWidget {
  final List<double> monthlyData;
  final String title;
  final Color barColor;

  const ConsumptionChart({
    super.key,
    required this.monthlyData,
    required this.title,
    this.barColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) {
      return Card(
        child: Center(
          child: Text('Aucune donnée disponible'),
        ),
      );
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: monthlyData.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.shade800,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String month = _getMonth(groupIndex);
                        return BarTooltipItem(
                          '$month\n${rod.toY.round()} kWh',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              _getMonth(value.toInt()).substring(0, 3),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: monthlyData.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final double value = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: barColor,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Consommation mensuelle (kWh)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int index) {
    const months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return months[index % 12];
  }
}

class ConsumptionChartConstants {
  static const double chartHeight = 200.0;
  static const double barWidth = 16.0;
  static const double cornerRadius = 6.0;
  static const double padding = 16.0;
  // ... autres constantes
}
