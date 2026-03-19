import 'package:flutter/material.dart';

class TowerInfoPanel extends StatelessWidget {
  final String name;
  final int cost;
  final int damage;
  final double range;
  final double attackSpeed;

  const TowerInfoPanel({
    Key? key,
    required this.name,
    required this.cost,
    required this.damage,
    required this.range,
    required this.attackSpeed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8.0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tower Name: $name',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Cost: \$cost'),
          SizedBox(height: 4),
          Text('Damage: $damage'),
          SizedBox(height: 4),
          Text('Range: ${range.toStringAsFixed(1)} units'),
          SizedBox(height: 4),
          Text('Attack Speed: ${attackSpeed.toStringAsFixed(2)} sec'),
        ],
      ),
    );
  }
}