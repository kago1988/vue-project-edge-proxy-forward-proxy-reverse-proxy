// src/main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Allow your frontend origin here
app.enableCors({
  origin: [
    'http://localhost:8080',
  ],
});

  await app.listen(3000);
  console.log('🚀 API running on http://localhost:3000');
}
bootstrap();
