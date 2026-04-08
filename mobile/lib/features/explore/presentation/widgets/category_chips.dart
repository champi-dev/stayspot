import 'package:flutter/material.dart';
import 'package:stayspot/app/theme.dart';

class CategoryChip {
  final String label;
  final IconData icon;

  const CategoryChip({required this.label, required this.icon});
}

const categories = [
  CategoryChip(label: 'Beach', icon: Icons.beach_access),
  CategoryChip(label: 'Mountain', icon: Icons.terrain),
  CategoryChip(label: 'City', icon: Icons.location_city),
  CategoryChip(label: 'Countryside', icon: Icons.grass),
  CategoryChip(label: 'Lake', icon: Icons.water),
  CategoryChip(label: 'Design', icon: Icons.architecture),
  CategoryChip(label: 'Tropical', icon: Icons.spa),
];

class CategoryChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CategoryChips({
    super.key,
    this.selectedIndex = -1,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onSelected(index == selectedIndex ? -1 : index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category.icon,
                  size: 24,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2,
                  width: 40,
                  color: isSelected ? AppColors.textPrimary : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
