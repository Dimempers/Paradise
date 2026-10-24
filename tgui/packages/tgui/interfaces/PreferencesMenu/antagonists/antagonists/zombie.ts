import { type Antagonist, Category } from '../base';

const Zombie: Antagonist = {
  key: 'zombie',
  name: 'Зомби',
  description: [
    `Гниющий мертвец, ведомый неутолимым голодом.`,
    `Занимайте тела безмозглых зомби, рвите живых когтями и разносите заразу.`,
  ],
  category: Category.Midround,
};

export default Zombie;
