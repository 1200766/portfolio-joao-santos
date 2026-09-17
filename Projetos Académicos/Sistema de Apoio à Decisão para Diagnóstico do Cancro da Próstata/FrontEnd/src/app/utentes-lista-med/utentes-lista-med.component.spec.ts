import { ComponentFixture, TestBed } from '@angular/core/testing';

import { UtentesListaMedComponent } from './utentes-lista-med.component';

describe('UtentesListaMedComponent', () => {
  let component: UtentesListaMedComponent;
  let fixture: ComponentFixture<UtentesListaMedComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ UtentesListaMedComponent ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(UtentesListaMedComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
