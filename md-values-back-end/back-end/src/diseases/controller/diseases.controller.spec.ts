import { Test, TestingModule } from '@nestjs/testing';
import { DiseasesController } from './diseases.controller';

describe('DiseasesController', () => {
  let controller: DiseasesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [DiseasesController],
    }).compile();

    controller = module.get<DiseasesController>(DiseasesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
