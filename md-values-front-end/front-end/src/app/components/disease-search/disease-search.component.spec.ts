import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DiseaseSearchComponent } from './disease-search.component';

describe('DiseaseSearchComponent', () => {
  let component: DiseaseSearchComponent;
  let fixture: ComponentFixture<DiseaseSearchComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DiseaseSearchComponent]
    })
    .compileComponents();
    
    fixture = TestBed.createComponent(DiseaseSearchComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
